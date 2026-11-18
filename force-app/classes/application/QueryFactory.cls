public class QueryFactory extends Application.Factory implements IQueryFactory {
  //* Exception class
  public class QueryFactoryException extends Exception {
  }

  //* Cache for default fields by model
  private Map<IModel, IQueryFields> defaultFieldsMap = new Map<IModel, IQueryFields>();

  //* Default field scope for queries
  private IFieldScope defaultFieldScope {
    get {
      if (defaultFieldScope == null) {
        defaultFieldScope = FieldScope.make(FieldScope.Trait.UNDERSIZE)
          .exclude(FieldScope.make('LastReferencedDate'))
          .exclude(FieldScope.make('LastViewedDate'))
          .exclude(FieldScope.make('.*Preferences.*'))
          .exclude(FieldScope.make('.*Permissions.*'))
          .exclude(FieldScope.make(FieldScope.Trait.FORMULA))
          .exclude(FieldScope.make(FieldScope.Trait.NAMESPACED));
      }
      return defaultFieldScope;
    }
    private set;
  }

  public QueryFactory(ICore core, Map<Type, Type> registry) {
    super(core, registry);
  }

  public QueryFactory(ICore core) {
    super(core, new Map<Type, Type>());
  }

  //* Override validation to ensure query classes implement IQuery and key is SObject
  protected override Boolean isValidPair(Type key, Type value) {
    if (value == null || key == null)
      return false;
    return IQuery.class.isAssignableFrom(value) &&
      SObject.class.isAssignableFrom(key);
  }

  //* Configure default field scope for all queries
  public QueryFactory defaultFieldScope(IFieldScope scope) {
    this.defaultFieldScope = scope;
    this.defaultFieldsMap = new Map<IModel, IQueryFields>();
    return this;
  }

  //* Helper method to get or create default fields for a model
  private IQueryFields getDefaultQueryFields(IModel source) {
    if (source == null) {
      return null;
    }

    IQueryFields ret = defaultFieldsMap.get(source);

    if (ret == null) {
      Type impClass = getType(source);
      set<sobjectfield> defaultFields;
      if (impClass != null && Query.class.isAssignableFrom(impClass)) {
        Query q = (Query) core.injector().newInstance(impClass);
        q.init(source);
        defaultFields = q.getDefaultFields();
      } else if (defaultFieldScope != null) {
        defaultFields = grantable(source, defaultFieldScope.apply(source));
      }
      ret = new QueryFields(source);
      if (defaultFields != null) {
        ret.add(defaultFields);
      } else {
        ret.addAll();
      }
      defaultFieldsMap.put(source, ret);
    }

    return ret;
  }

  // Leaves out fields no user can be given access to: license-gated fields such as Einstein Account
  // Tier, which describes list but queries and searches can reject.
  private static Set<SObjectField> grantable(IModel model, Set<SObjectField> fields) {
    Set<SObjectField> kept = new Set<SObjectField>();
    for (SObjectField field : fields) {
      DescribeFieldResult described = model.scheme().getFieldDescribe(field);
      if (described.isAccessible() || described.isPermissionable()) {
        kept.add(field);
      }
    }
    return kept;
  }

  private type getType(IModel model) {
    Type key = core.injector().getType(model?.name());
    return getRegisteredClass(key);
  }

  //* Primary factory method - create Query instances with SObjectType
  //* Ensures Scheme isolation by always rebuilding model from this Core's scheme
  public IQuery make(SObjectType token) {
    if (token == null) {
      throw new QueryFactoryException('SObjectType token cannot be null');
    }

    // CRITICAL: Always rebuild model using this Core's Scheme (prevents cross-Application contamination)
    IModel model = core.model(token);

    Type key = core.injector().getType(model.name());
    Type impClass = getType(model);

    IQuery q;
    if (impClass != null) {
      Query qImp = (Query) core.injector().newInstance(impClass);
      qImp.init(model);
      q = qImp;
    } else {
      q = model.query();
    }
    IQueryFields defaultFields = getDefaultQueryFields(model);
    q.fields().add(defaultFields);
    if (q instanceof Query) {
      ((Query) q).markDefaults(defaultFields.getFieldsByReference().get(model));
    }
    return q;
  }

  //* Factory method with name (extracts token, flows through make(SObjectType))
  public IQuery make(String name) {
    if (name == null) {
      throw new QueryFactoryException('Object name cannot be null');
    }
    SObjectType token = core.model(name).token();
    return make(token);
  }

  //* Factory method with name and additive arguments
  public IQuery make(String name, List<Object> additiveArgs) {
    IQuery query = make(name);
    return applyAdditiveArgs(query, additiveArgs);
  }

  //* Factory method with token and additive arguments
  public IQuery make(SObjectType token, List<Object> additiveArgs) {
    IQuery query = make(token);
    return applyAdditiveArgs(query, additiveArgs);
  }

  //* Helper method to apply additive arguments to a query
  private IQuery applyAdditiveArgs(IQuery query, List<Object> additiveArgs) {
    if (additiveArgs == null || additiveArgs.isEmpty()) {
      return query;
    }

    for (Object arg : additiveArgs) {
      applyAdditiveArg(query, arg);
    }

    return query;
  }

  //* Apply a single additive argument to the query with strict validation
  private void applyAdditiveArg(IQuery q, Object arg) {
    if (arg == null) {
      return;
    }

    IModel queryModel = q.source();
    SObjectType queryToken = queryModel.token();

    // Try to interpret as IPath first
    IPath path = queryModel.path(arg, false, false);
    if (path != null) {
      // VALIDATION: Verify path originates from the correct SObjectType
      if (path.source().token() != queryToken) {
        throw new QueryFactoryException(
          'IPath ' +
            path.toString() +
            ' originates from ' +
            path.source().name() +
            ' but query is for ' +
            queryModel.name() +
            '. Wrong model.'
        );
      }

      // VALIDATION: Verify path is a reference field (FK)
      Schema.DisplayType fieldType = path.describe().getType();
      if (fieldType != Schema.DisplayType.REFERENCE) {
        throw new QueryFactoryException(
          'Field ' +
            path.toString() +
            ' (type: ' +
            fieldType +
            ') is not a reference field. ' +
            'Only lookup/master-detail fields can be expanded into foreign field queries.'
        );
      }

      // Valid FK path - add foreign fields
      addForeignFields(q, path);
      return;
    }

    // Not an IPath - try other argument types
    Schema.ChildRelationship cr;

    if (arg instanceof String) {
      String strArg = (String) arg;

      // Try as child relationship name
      cr = queryModel.getChildRelationship(strArg);

      if (cr == null) {
        // VALIDATION: String is neither a valid path nor child relationship
        throw new QueryFactoryException(
          'String "' +
            strArg +
            '" is not a valid child relationship name for ' +
            queryModel.name() +
            '. ' +
            'Expected a child relationship like "Contacts" or "Opportunities".'
        );
      }
    } else if (arg instanceof SObjectField) {
      SObjectField field = (SObjectField) arg;

      // Try as child relationship field
      cr = queryModel.getChildRelationship(field);

      if (cr == null) {
        // VALIDATION: Field is not a valid child relationship
        DescribeFieldResult fieldDescribe = queryModel.scheme()
          .getFieldDescribe(field);
        SObjectType fieldToken = fieldDescribe.getSObjectType();
        DescribeSObjectResult sobjectDescribe = queryModel.scheme()
          .getDescribe(fieldToken);
        throw new QueryFactoryException(
          'Field ' +
            fieldDescribe.getName() +
            ' from ' +
            sobjectDescribe.getName() +
            ' does not belong to ' +
            queryModel.name() +
            ' and is not a valid child relationship field. ' +
            'Check that the field defines a lookup/master-detail to ' +
            queryModel.name() +
            '.'
        );
      }
    } else if (arg instanceof ICondition) {
      // Add condition to query filters
      q.filters().add((ICondition) arg);
      return;
    } else if (arg instanceof Set<String>) {
      // VALIDATION: Verify all string field names are valid
      Set<String> fieldNames = (Set<String>) arg;
      Set<String> validFieldNames = queryModel.fieldMap().keySet();
      for (String fieldName : fieldNames) {
        if (!validFieldNames.contains(fieldName.toLowerCase())) {
          String validFieldsList = String.join(
            new List<String>(validFieldNames),
            ', '
          );
          String fieldsPreview = validFieldsList.length() > 200
            ? validFieldsList.substring(0, 200) +
              '... (' +
              validFieldNames.size() +
              ' total fields)'
            : validFieldsList;
          throw new QueryFactoryException(
            'Field name "' +
              fieldName +
              '" does not exist on ' +
              queryModel.name() +
              '. ' +
              'Valid field names: ' +
              fieldsPreview
          );
        }
      }
      q.fields().add(fieldNames);
      return;
    } else if (arg instanceof Set<SObjectField>) {
      // VALIDATION: Verify all fields belong to this SObjectType
      Set<SObjectField> fields = (Set<SObjectField>) arg;
      for (SObjectField field : fields) {
        DescribeFieldResult fieldDescribe = queryModel.scheme()
          .getFieldDescribe(field);
        SObjectType fieldToken = fieldDescribe.getSObjectType();
        if (fieldToken != queryToken) {
          DescribeSObjectResult sobjectDescribe = queryModel.scheme()
            .getDescribe(fieldToken);
          throw new QueryFactoryException(
            'Field ' +
              fieldDescribe.getName() +
              ' belongs to ' +
              sobjectDescribe.getName() +
              ' but query is for ' +
              queryModel.name() +
              '. ' +
              'All fields must belong to the same SObject.'
          );
        }
      }
      q.fields().add(fields);
      return;
    } else if (arg instanceof Set<IPath>) {
      // VALIDATION: Verify all paths originate from this SObjectType
      Set<IPath> paths = (Set<IPath>) arg;
      for (IPath p : paths) {
        if (p.source().token() != queryToken) {
          throw new QueryFactoryException(
            'IPath ' +
              p.toString() +
              ' originates from ' +
              p.source().name() +
              ' but query is for ' +
              queryModel.name() +
              '. All paths must originate from the same model.'
          );
        }
      }
      q.fields().add(paths);
      return;
    } else if (arg instanceof IFieldScope) {
      // Field scope is always valid (applies to any model)
      q.fields().add((IFieldScope) arg);
      return;
    } else if (arg instanceof IQueryFields) {
      // VALIDATION: Verify QueryFields source matches query model
      IQueryFields fields = (IQueryFields) arg;
      if (fields.source().token() != queryToken) {
        throw new QueryFactoryException(
          'IQueryFields for ' +
            fields.source().name() +
            ' cannot be added to ' +
            queryModel.name() +
            ' query. Source models must match.'
        );
      }
      q.fields().add(fields);
      return;
    } else {
      // VALIDATION: Unknown argument type
      String argStr = String.valueOf(arg);
      String argPreview = argStr.length() > 100
        ? argStr.substring(0, 100) + '...'
        : argStr;
      throw new QueryFactoryException(
        'Unsupported additive argument type: ' +
          argPreview +
          '. Expected: IPath (FK field), String (child relationship), SObjectField, ICondition, ' +
          'Set<String>, Set<SObjectField>, Set<IPath>, IFieldScope, or IQueryFields.'
      );
    }

    // If we got here, cr is not null (child relationship found)
    if (cr != null) {
      IQuery sq = make(cr.getChildSObject());
      q.addSubquery(cr.getField(), sq);
    }
  }

  //* Add fields from referenced objects (equivalent to SelectorFactory.addForeignFields)
  private void addForeignFields(IQuery query, IPath path) {
    List<SObjectType> refTokens = path.describe().getReferenceTo();
    if (refTokens != null && !refTokens.isEmpty()) {
      for (SObjectType refToken : refTokens) {
        // Use the default field caching mechanism for each referenced object
        IModel refModel = core.model(refToken);
        IQueryFields defaultFields = getDefaultQueryFields(refModel);
        if (defaultFields != null) {
          query.fields().add(path, defaultFields);
        }
      }
    }
  }
}
