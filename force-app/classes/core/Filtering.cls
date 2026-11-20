/**
 * Builds condition trees. A LogicalCondition is a branch that combines its children with AND or
 * OR (optionally negated); a FieldCondition is a leaf comparing one field path with a value. A
 * tree is bound to one SObjectType ("realized") and can then test records in memory or compile
 * into a SOQL WHERE clause through ConditionCompilation.
 */
public class Filtering {
  public class ConditionException extends Exception {
  }

  public class RealizeException extends Exception {
    public RealizeException(SObjectType offered, SObjectType bound) {
      this('Upstream SObjectType ' + offered + ' does not match current SObjectType ' + bound);
    }
  }

  private Core core;

  public Filtering(Core core) {
    if (core == null) {
      throw new ConditionException('Filtering needs a core: core must not be null');
    }
    this.core = core;
  }

  // Leaves

  public FieldCondition fieldCondition(Enums.Comparator kind, Object left, Object right) {
    return fieldCondition(kind, left, right, false);
  }

  /**
   * `left` names the field: an IPath, IReference, SObjectField, List<SObjectField> (a path across
   * lookups), a field name (resolved once the condition is realized), or an IAggregateFunction
   * for HAVING clauses.
   *
   * `right` is the value. With IN or NOT IN it may be an IQuery instead of a list or set: a
   * semi-join or anti-join, written as Field IN (SELECT ... FROM ...). `left` is then an Id or
   * lookup field, and the query selects the one Id or lookup field to match it against.
   *
   * On a date or date-time field it may be a date literal (DateLiteral.lastNDays(30)), or with IN
   * and NOT IN a List<IDateLiteral>. It is written into the SOQL as it is, and never bound.
   */
  public FieldCondition fieldCondition(Enums.Comparator kind, Object left, Object right, Boolean inverted) {
    return new FieldCondition(null, left, kind, right, inverted, this);
  }

  // Branches

  /** Every child must hold (AND). */
  public LogicalCondition all(List<ICondition> members) {
    return logicalCondition(false, false, members);
  }

  /** At least one child must hold (OR). */
  public LogicalCondition any(List<ICondition> members) {
    return logicalCondition(true, false, members);
  }

  public LogicalCondition logicalCondition(Boolean orJoined, Boolean inverted, List<ICondition> members) {
    LogicalCondition branch = new LogicalCondition(null, orJoined, inverted, members, this);
    return branch;
  }

  public class LogicalCondition implements ILogicalCondition {
    public Boolean disjunction;
    public Boolean negated;
    private IModel source;
    private Filtering owner;
    private List<ICondition> members;

    /** The list is used as given (not copied); a type realizes the branch straight away. */
    public LogicalCondition(
      SObjectType boundTo,
      Boolean orJoined,
      Boolean inverted,
      List<ICondition> members,
      Filtering owner
    ) {
      disjunction = orJoined;
      negated = inverted;
      this.members = members ?? new List<ICondition>();
      this.owner = owner;
      if (boundTo != null) {
        realize(boundTo);
      }
    }

    // Same joiner and negation, no members, not yet realized.
    private LogicalCondition emptyCopy() {
      return new LogicalCondition(null, disjunction, negated, null, owner);
    }

    public List<ICondition> getAll() {
      List<ICondition> snapshot = members.clone();
      return snapshot;
    }

    public IModel source() {
      return source;
    }

    public void setNegated(Boolean inverted) {
      negated = inverted;
    }

    public Boolean isNegated() {
      return negated == true;
    }

    /** Ignores null. Once the branch is realized, the member is realized to match. */
    public LogicalCondition add(ICondition member) {
      if (member != null) {
        if (source != null) {
          member.realize(source.token());
        }
        members.add(member);
      }
      return this;
    }

    public LogicalCondition addAll(List<ICondition> additions) {
      for (ICondition member : additions ?? new List<ICondition>()) {
        add(member);
      }
      return this;
    }

    public LogicalCondition clear() {
      members = new List<ICondition>();
      return this;
    }

    /** A deep copy clones every member as well; a shallow copy shares them. */
    public LogicalCondition clone(Boolean deep) {
      LogicalCondition copy = emptyCopy();
      copy.source = source;
      if (deep != true) {
        copy.members = members.clone();
        return copy;
      }
      for (ICondition member : members) {
        copy.members.add(member.clone(true));
      }
      return copy;
    }

    /** Binds the branch and every member to the type; a branch bound to another type throws. */
    public void realize(SObjectType target) {
      if (target == null) {
        throw new RealizeException('Cannot realize: SObjectType argument must not be null');
      }
      if (source != null && target != source.token()) {
        throw new RealizeException(target, source.token());
      }
      source = source ?? owner.core.model(target);
      for (ICondition member : members) {
        if (member != null) {
          member.realize(target);
        }
      }
    }

    // The first source found depth-first, adopted (unrealized) by this branch.
    private IModel inferSource() {
      for (Integer at = 0; source == null && at < members.size(); at++) {
        ICondition member = members[at];
        source = member.source();
        if (source == null && member instanceof LogicalCondition) {
          source = ((LogicalCondition) member).inferSource();
        }
      }
      return source;
    }

    /** Tests the record in memory. An empty AND holds; an empty OR does not. */
    public Boolean evaluate(SObject candidate) {
      return test(candidate) == true;
    }

    /**
     * The test with SOQL's third answer. Null means "unknown": SOQL cannot say whether an empty
     * number or date is greater than a value, and leaves such a row out even under NOT. An AND is
     * unknown when no member fails and one is unknown; an OR, when no member holds and one is
     * unknown; and NOT leaves unknown as it is.
     */
    public Boolean test(SObject candidate) {
      if (candidate == null) {
        throw new ConditionException('Cannot evaluate null record: there is nothing to test');
      }
      SObjectType candidateType = candidate.getSObjectType();
      // Once bound to the type, members realize themselves as they evaluate.
      if (source == null || source.token() != candidateType) {
        realize(candidateType);
      }
      Boolean seekingAny = disjunction == true;
      Boolean outcome = !seekingAny;
      Boolean unknown = false;
      for (Integer at = 0; at < members.size() && outcome != seekingAny; at++) {
        Boolean answer = testMember(members[at], candidate);
        if (answer == null) {
          unknown = true;
        } else if (answer == seekingAny) {
          outcome = seekingAny;
        }
      }
      if (unknown && outcome != seekingAny) {
        return null;
      }
      return negated == true ? !outcome : outcome;
    }

    /**
     * The branch as format markup, e.g. ({0} AND ({1} OR {2})). A branch with nothing in it is
     * written as a constant test: an empty AND always holds, and an empty OR never does.
     */
    public String compile(IConditionCompilation compilation) {
      String joiner = disjunction == true ? ' OR ' : ' AND ';
      String grouped = '';
      for (ICondition member : members) {
        String part = member?.compile(compilation);
        if (part != null) {
          grouped += (grouped == '' ? '' : joiner) + part;
        }
      }
      if (grouped == '') {
        grouped = ((ConditionCompilation) compilation).constant(disjunction != true);
      } else {
        grouped = '(' + grouped + ')';
      }
      return negated == true ? '(NOT ' + grouped + ')' : grouped;
    }

    /** The same branch seen from the reference's source, with each member moved along it. */
    public LogicalCondition prepend(IReference via) {
      realize(via.target().token());
      LogicalCondition moved = emptyCopy();
      moved.realize(via.source().token());
      for (ICondition member : members) {
        if (member != null) {
          moved.add(member.prepend(via));
        }
      }
      return moved;
    }

    public String toSoql() {
      if (inferSource() == null) {
        throw new ConditionException('Cannot generate SOQL: condition has no source. Call realize() first.');
      }
      IConditionCompilation compiled = source.compileCondition(this);
      return compiled.toSoql();
    }
  }

  public class FieldCondition implements IFieldCondition {
    private Filtering owner;
    private Enums.Comparator kind;
    private Object operand;
    private Boolean negated;
    private Typing.Comparison comparison;
    private String pendingPath;
    private IAggregateFunction aggregate;
    private SObjectType boundType;
    // A semi-join or anti-join: the query on the right, and the field on the left. The field is
    // held here because a Comparison types a value, and a query is not one.
    private IQuery innerQuery;
    private IPath joinPath;

    private FieldCondition(
      SObjectType boundTo,
      Object left,
      Enums.Comparator kind,
      Object right,
      Boolean inverted,
      Filtering owner
    ) {
      if (kind == null) {
        throw new ConditionException('A field condition needs an operator');
      }
      if (left == null) {
        throw new ConditionException('A field condition needs a field to compare');
      }
      this.owner = owner;
      this.kind = kind;
      operand = right;
      negated = inverted;
      if (right instanceof IQuery) {
        if (kind != Enums.Comparator.IIN && kind != Enums.Comparator.NIN) {
          throw new ConditionException(
            'A query can be the value of IN or NOT IN only (a semi-join or anti-join), not of ' + kind
          );
        }
        if (left instanceof IAggregateFunction) {
          throw new ConditionException('Cannot match ' + left + ' against a query: HAVING takes no semi-join');
        }
        innerQuery = (IQuery) right;
      }
      if (left instanceof IAggregateFunction) {
        if (right instanceof List<IDateLiteral>) {
          throw new ConditionException('Cannot compare ' + left + ' with a list of date literals: HAVING takes one');
        }
        aggregate = (IAggregateFunction) left;
        return;
      }
      IPath resolved = resolve(boundTo, left);
      if (resolved != null) {
        bind(resolved);
      } else if (String.isBlank(pendingPath)) {
        throw new ConditionException('Cannot compare by ' + left + ': not a field, path, reference or field name');
      }
      if (boundTo != null) {
        realize(boundTo);
      }
    }

    // A field name without a type is kept until the condition is realized.
    private IPath resolve(SObjectType boundTo, Object left) {
      if (left instanceof IPath) {
        return (IPath) left;
      } else if (left instanceof IReference) {
        return ((IReference) left).toPath();
      } else if (left instanceof SObjectField) {
        return owner.core.path((SObjectField) left);
      } else if (left instanceof List<SObjectField>) {
        return owner.core.path((List<SObjectField>) left);
      } else if (left instanceof String && boundTo != null) {
        return owner.core.model(boundTo).path((String) left, true, true);
      } else if (left instanceof String) {
        pendingPath = (String) left;
      }
      return null;
    }

    private void bind(IPath fieldPath) {
      hold(fieldPath);
      realize(fieldPath.source().token());
    }

    // Takes the field: as a typed comparison with the value, or as the left side of a semi-join.
    // The value is then the one the comparison holds, which is what a query binds.
    private void hold(IPath fieldPath) {
      if (innerQuery == null) {
        comparison = Typing.comparison(fieldPath, kind, operand);
        operand = comparison.value();
        return;
      }
      if (fieldPath.describe().getSoapType() != SoapType.ID) {
        throw new ConditionException(
          fieldPath.name() + ' is not an Id or lookup field, so it cannot be matched against a query (a semi-join)'
        );
      }
      joinPath = fieldPath;
    }

    public Boolean isAggregateCondition() {
      return aggregate != null;
    }

    /** The right-hand value; for a semi-join or anti-join, the inner IQuery. */
    public Object value() {
      return operand;
    }

    public Enums.Comparator operator() {
      return kind;
    }

    public IPath path() {
      if (innerQuery != null) {
        return joinPath;
      }
      return comparison == null ? null : comparison.path();
    }

    public IModel source() {
      IPath fieldPath = path();
      return fieldPath == null ? null : fieldPath.source();
    }

    public void setNegated(Boolean inverted) {
      negated = inverted;
    }

    public Boolean isNegated() {
      return negated == true;
    }

    /**
     * A leaf holds no members, so a shallow copy is complete, but for one thing: a deep copy of a
     * semi-join copies its inner query too, so the copy's query can change without the original's.
     */
    public FieldCondition clone(Boolean deep) {
      FieldCondition copy = clone();
      if (deep == true && innerQuery != null) {
        copy.innerQuery = innerQuery.deepClone();
        copy.operand = copy.innerQuery;
      }
      return copy;
    }

    /**
     * Resolves a pending field name against the type, or checks the bound type matches. An
     * aggregate function only notes the type, to tell what kind of field it is over.
     */
    public void realize(SObjectType target) {
      if (aggregate != null) {
        boundType = target ?? boundType;
        return;
      }
      if (target == null) {
        throw new ConditionException('Cannot realize a field condition without an SObjectType');
      }
      if (target == boundType) {
        return;
      }
      if (path() != null) {
        SObjectType current = source().token();
        if (target != current) {
          throw new RealizeException(target, current);
        }
      } else {
        hold(owner.core.model(target).path(pendingPath, true, true));
      }
      boundType = target;
    }

    public Boolean evaluate(SObject candidate) {
      return test(candidate) == true;
    }

    /**
     * The test with SOQL's third answer: null when SOQL cannot say, and so leaves the row out
     * whether or not the condition is negated. That is the case for an empty number, date,
     * date-time or time compared with <, <=, > or >=, and for an empty date compared with a date
     * literal by anything but !=.
     */
    public Boolean test(SObject candidate) {
      if (aggregate != null) {
        throw new ConditionException('Cannot evaluate aggregate function conditions in-memory');
      }
      if (innerQuery != null) {
        throw new ConditionException('Cannot evaluate a semi-join in memory: its inner query has not been run');
      }
      if (candidate == null) {
        throw new ConditionException('Cannot evaluate null record: there is nothing to test');
      }
      realize(candidate.getSObjectType());
      Boolean holds = comparison.evaluate(candidate);
      if (holds == null) {
        return null;
      }
      return negated == true ? !holds : holds;
    }

    /** Registers the leaf with the compilation and returns its {n} placeholder. */
    public String compile(IConditionCompilation compilation) {
      return compile(((ConditionCompilation) compilation).leaves);
    }

    public String compile(List<IFieldCondition> collected) {
      Integer position = collected.size();
      collected.add(this);
      return '{' + position + '}';
    }

    /** The same condition reached through the reference, from its source object. */
    public FieldCondition prepend(IReference via) {
      if (aggregate != null) {
        throw new ConditionException('Cannot prepend reference to aggregate function conditions');
      }
      realize(via.target().token());
      return new FieldCondition(null, via.path(path()), kind, operand, negated, owner);
    }

    /**
     * The condition with the given text (such as a bind variable) as its value. For a semi-join
     * the text is the inner query, in parentheses.
     */
    public String toSoql(String literal) {
      String clause;
      if (aggregate != null) {
        clause = aggregate.toSoql() + ' ' + aggregateKeyword() + ' ' + (literal ?? aggregateLiteral());
      } else if (path() == null) {
        throw new ConditionException('Cannot generate SOQL for ' + pendingPath + ' before realize()');
      } else if (innerQuery != null) {
        String innerSoql = literal ?? Query.semiJoinSoql(innerQuery, null);
        clause = joinPath.name() + ' ' + Typing.operator(kind).toSoql() + ' ' + innerSoql;
      } else {
        clause = literal == null ? comparison.toSoql() : comparison.toSoql(literal);
      }
      return negated == true ? '(NOT ' + clause + ')' : clause;
    }

    /** The condition with its value inline; a semi-join's inner query has its values inline too. */
    public String toSoql() {
      return toSoql((String) null);
    }

    // HAVING compares one aggregate with one value, so only =, !=, <, >, <= and >= apply, and
    // with null only = and !=.
    private String aggregateKeyword() {
      Typing.Operator op = Typing.operator(kind);
      if (op.isPlural() || kind == Enums.Comparator.LK) {
        throw new ConditionException('Unsupported operator for aggregate function: ' + kind);
      }
      if (operand == null && kind != Enums.Comparator.EQ && kind != Enums.Comparator.NE) {
        throw new ConditionException(
          'Cannot compare ' + aggregate.toSoql() + ' with null by ' + kind + ': null goes with EQ and NE'
        );
      }
      return op.toSoql();
    }

    // The value of a HAVING condition, written inline the way Typing writes one. A date literal
    // is written as one of the framework's own, so that text from another class is checked first.
    // A Date against the earliest or latest date-time is midnight GMT, as it is for such a field.
    private String aggregateLiteral() {
      if (operand instanceof IDateLiteral) {
        return DateLiteral.checked((IDateLiteral) operand).toSoql();
      }
      Typing.Evaluator evaluator = Typing.getSoapyValue(operand, null)?.getEvaluator();
      List<String> literals = evaluator instanceof Typing.DatetimeEvaluator
        ? ((Typing.DatetimeEvaluator) evaluator).itemsToSoql(aggregatedType() == SoapType.DATETIME)
        : evaluator?.itemsToSoql();
      return literals == null || literals.isEmpty() ? String.valueOf(operand) : literals[0];
    }

    // The type of the field the aggregate function is over; null when it cannot be told.
    private SoapType aggregatedType() {
      Object over = aggregate.field();
      if (over instanceof SObjectField) {
        return owner.core.path((SObjectField) over).describe().getSoapType();
      }
      if (over instanceof String && boundType != null) {
        over = owner.core.model(boundType).path((String) over);
      }
      return over instanceof IPath ? ((IPath) over).describe()?.getSoapType() : null;
    }
  }

  // A member's answer: true, false, or null for unknown. A condition of another class has two answers.
  private static Boolean testMember(ICondition member, SObject candidate) {
    if (member instanceof FieldCondition) {
      return ((FieldCondition) member).test(candidate);
    }
    if (member instanceof LogicalCondition) {
      return ((LogicalCondition) member).test(candidate);
    }
    return member.evaluate(candidate);
  }

  /**
   * A condition tree compiled for one SObjectType: the markup has a {n} placeholder for each leaf,
   * in the order the leaves are listed, ready for String.format.
   */
  public class ConditionCompilation implements IConditionCompilation {
    public String markup;
    private IModel source;
    private Boolean grouped;
    private List<FieldCondition> leaves = new List<FieldCondition>();

    public ConditionCompilation(SObjectType target, ICondition root, Filtering owner) {
      this(owner.core.model(target), root, false);
    }

    /** With `grouped`, for a HAVING clause: it takes no bare field, so its constants are counts. */
    public ConditionCompilation(IModel source, ICondition root, Boolean grouped) {
      this.source = source;
      this.grouped = grouped == true;
      root.realize(source.token());
      markup = root.compile(this);
    }

    // The text of a branch with nothing in it: a test that always holds, or never does.
    private String constant(Boolean always) {
      return Typing.constantSoql(source, always, grouped);
    }

    /** Every leaf written inline. */
    public String toSoql() {
      String[] clauses = new String[leaves.size()];
      for (Integer at = 0; at < leaves.size(); at++) {
        clauses[at] = leaves[at].toSoql();
      }
      return String.format(markup, clauses);
    }

    public Set<IPath> getPaths() {
      Set<IPath> reached = new Set<IPath>();
      for (FieldCondition leaf : leaves) {
        reached.add(leaf.path());
      }
      return reached;
    }

    public List<FieldCondition> getFieldConditions() {
      return leaves.clone();
    }

    public String getMarkup() {
      return markup;
    }

    public IModel source() {
      return source;
    }
  }
}
