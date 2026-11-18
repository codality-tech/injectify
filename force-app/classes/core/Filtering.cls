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
      for (Integer at = 0; at < members.size() && outcome != seekingAny; at++) {
        if (members[at].evaluate(candidate) == seekingAny) {
          outcome = seekingAny;
        }
      }
      return negated == true ? !outcome : outcome;
    }

    /** The branch as format markup, e.g. ({0} AND ({1} OR {2})); null when it has no leaves. */
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
        return null;
      }
      grouped = '(' + grouped + ')';
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
      if (left instanceof IAggregateFunction) {
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
      comparison = Typing.comparison(fieldPath, kind, operand);
      realize(fieldPath.source().token());
    }

    public Boolean isAggregateCondition() {
      return aggregate != null;
    }

    public Object value() {
      return operand;
    }

    public Enums.Comparator operator() {
      return kind;
    }

    public IPath path() {
      return comparison == null ? null : comparison.path();
    }

    public IModel source() {
      IPath fieldPath = path();
      return fieldPath == null ? null : fieldPath.source();
    }

    public void setNegated(Boolean inverted) {
      negated = inverted;
    }

    /** Leaves hold no members, so a shallow copy is complete. */
    public FieldCondition clone(Boolean deep) {
      return clone();
    }

    /** Resolves a pending field name against the type, or checks the bound type matches. */
    public void realize(SObjectType target) {
      if (aggregate != null) {
        return;
      }
      if (target == null) {
        throw new ConditionException('Cannot realize a field condition without an SObjectType');
      }
      if (target == boundType) {
        return;
      }
      if (comparison != null) {
        SObjectType current = source().token();
        if (target != current) {
          throw new RealizeException(target, current);
        }
      } else {
        IPath fieldPath = owner.core.model(target).path(pendingPath, true, true);
        comparison = Typing.comparison(fieldPath, kind, operand);
      }
      boundType = target;
    }

    public Boolean evaluate(SObject candidate) {
      if (aggregate != null) {
        throw new ConditionException('Cannot evaluate aggregate function conditions in-memory');
      }
      if (candidate == null) {
        throw new ConditionException('Cannot evaluate null record: there is nothing to test');
      }
      realize(candidate.getSObjectType());
      Boolean holds = comparison.evaluate(candidate);
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

    /** The condition with the given text (such as a bind variable) as its value. */
    public String toSoql(String literal) {
      String clause;
      if (aggregate != null) {
        clause = aggregate.toSoql() + ' ' + aggregateKeyword() + ' ' + (literal ?? inlineLiteral(operand));
      } else if (comparison == null) {
        throw new ConditionException('Cannot generate SOQL for ' + pendingPath + ' before realize()');
      } else {
        clause = literal == null ? comparison.toSoql() : comparison.toSoql(literal);
      }
      return negated == true ? '(NOT ' + clause + ')' : clause;
    }

    /** The condition with its value inline. */
    public String toSoql() {
      return toSoql((String) null);
    }

    // HAVING compares one aggregate with one value, so only =, !=, <, >, <= and >= apply.
    private String aggregateKeyword() {
      Typing.Operator op = Typing.operator(kind);
      if (op.isPlural() || kind == Enums.Comparator.LK) {
        throw new ConditionException('Unsupported operator for aggregate function: ' + kind);
      }
      return op.toSoql();
    }
  }

  // Renders one value the way Typing writes inline literals.
  private static String inlineLiteral(Object operand) {
    Typing.Evaluator evaluator = Typing.getSoapyValue(operand, null)?.getEvaluator();
    List<String> literals = evaluator?.itemsToSoql();
    return literals == null || literals.isEmpty() ? String.valueOf(operand) : literals[0];
  }

  /**
   * A condition tree compiled for one SObjectType: the markup has a {n} placeholder for each leaf,
   * in the order the leaves are listed, ready for String.format.
   */
  public class ConditionCompilation implements IConditionCompilation {
    public String markup;
    private IModel source;
    private List<FieldCondition> leaves = new List<FieldCondition>();

    public ConditionCompilation(SObjectType target, ICondition root, Filtering owner) {
      source = owner.core.model(target);
      root.realize(target);
      markup = root.compile(this);
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
