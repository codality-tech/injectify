/**
 * Standalone tokenized parser for SOQL WHERE clause conditions.
 *
 * This parser is schema-independent and uses character-by-character tokenization
 * instead of regex patterns. It produces an intermediate parse tree that can be
 * converted to ICondition structures when schema information is available.
 *
 * ARCHITECTURE:
 *   1. Tokenize: String → List<Token> (lexical analysis)
 *   2. Parse: List<Token> → ParseNode (syntax analysis)
 *   3. Convert: ParseNode → ICondition (semantic analysis with schema)
 *
 * Example:
 * <pre>
 *   ConditionParser parser = new ConditionParser();
 *   ConditionParser.ParseNode tree = parser.parse("Name = 'Acme' AND CreatedDate >= 2023-12-25T10:30:00Z");
 *   ICondition condition = parser.toCondition(tree, filtering);
 * </pre>
 */
public class ConditionParser {
  public class ParseException extends Exception {
  }

  // ========== PHASE 1: TOKENIZATION ==========

  public enum TokenType {
    // Literals
    FIELD,
    STRING_LITERAL,
    NUMBER_LITERAL,
    DATE_LITERAL,
    DATETIME_LITERAL,
    BOOLEAN_LITERAL,
    NULL_VALUE,
    // Operators
    EQ,
    NE,
    LT,
    GT,
    LE,
    GE,
    LK,
    IIN,
    NIN,
    INC,
    EXC,
    // Logical
    OP_AND,
    OP_OR,
    OP_NOT,
    // Delimiters
    LPAREN,
    RPAREN,
    COMMA,
    EOF
  }

  public class Token {
    public TokenType type;
    public String value;
    public Integer position;

    public Token(TokenType type, String value, Integer position) {
      this.type = type;
      this.value = value;
      this.position = position;
    }
  }

  /**
   * Tokenize input string into list of tokens.
   * Uses character-by-character state machine for accurate parsing.
   */
  public List<Token> tokenize(String input) {
    List<Token> tokens = new List<Token>();
    Integer pos = 0;
    Integer len = input.length();

    while (pos < len) {
      String ch = input.substring(pos, pos + 1);

      // Skip whitespace
      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        pos++;
        continue;
      }

      // Parentheses
      if (ch == '(') {
        tokens.add(new Token(TokenType.LPAREN, '(', pos));
        pos++;
        continue;
      }
      if (ch == ')') {
        tokens.add(new Token(TokenType.RPAREN, ')', pos));
        pos++;
        continue;
      }

      // Comma
      if (ch == ',') {
        tokens.add(new Token(TokenType.COMMA, ',', pos));
        pos++;
        continue;
      }

      // String literal (single quotes)
      if (ch == '\'') {
        Integer start = pos;
        pos++; // Skip opening quote
        String value = '';
        while (pos < len) {
          String c = input.substring(pos, pos + 1);
          if (c == '\'') {
            // Check for escaped quote ('')
            if (pos + 1 < len && input.substring(pos + 1, pos + 2) == '\'') {
              value += '\'';
              pos += 2;
            } else {
              // End of string
              pos++;
              break;
            }
          } else {
            value += c;
            pos++;
          }
        }
        tokens.add(new Token(TokenType.STRING_LITERAL, value, start));
        continue;
      }

      // Numbers, dates, datetimes, booleans, NULL, keywords, fields, operators
      if (isAlphaNumeric(ch) || ch == '-' || ch == '+' || ch == '.') {
        Integer start = pos;
        String value = '';

        // Collect alphanumeric, dots, underscores, +, -, :, T, Z
        while (pos < len) {
          String c = input.substring(pos, pos + 1);
          if (
            isAlphaNumeric(c) ||
            c == '.' ||
            c == '_' ||
            c == '-' ||
            c == '+' ||
            c == ':' ||
            c == 'T' ||
            c == 'Z'
          ) {
            value += c;
            pos++;
          } else {
            break;
          }
        }

        // Classify the token
        Token tok = classifyToken(value, start);
        if (tok != null) {
          tokens.add(tok);
        } else {
          throw new ParseException(
            'Unrecognized token at position ' + start + ': ' + value
          );
        }
        continue;
      }

      // Operators: =, !=, <, >, <=, >=, !
      if (ch == '=' || ch == '!' || ch == '<' || ch == '>') {
        Integer start = pos;
        String value = ch;
        pos++;

        // Check for two-character operators
        if (pos < len) {
          String next = input.substring(pos, pos + 1);
          if (
            (ch == '!' &&
            next == '=') ||
            (ch == '<' &&
            next == '=') ||
            (ch == '>' &&
            next == '=')
          ) {
            value += next;
            pos++;
          }
        }

        TokenType type = null;
        if (value == '=')
          type = TokenType.EQ;
        else if (value == '!=')
          type = TokenType.NE;
        else if (value == '<')
          type = TokenType.LT;
        else if (value == '>')
          type = TokenType.GT;
        else if (value == '<=')
          type = TokenType.LE;
        else if (value == '>=')
          type = TokenType.GE;

        if (type != null) {
          tokens.add(new Token(type, value, start));
        } else {
          throw new ParseException(
            'Unrecognized operator at position ' + start + ': ' + value
          );
        }
        continue;
      }

      throw new ParseException(
        'Unexpected character at position ' + pos + ': ' + ch
      );
    }

    tokens.add(new Token(TokenType.EOF, '', pos));
    return tokens;
  }

  /**
   * Helper to check if character is alphanumeric
   */
  private Boolean isAlphaNumeric(String c) {
    return Pattern.matches('[a-zA-Z0-9]', c);
  }

  /**
   * Classify a token value (number, date, datetime, boolean, keyword, field, etc.)
   */
  private Token classifyToken(String value, Integer position) {
    String upper = value.toUpperCase();

    // Keywords (case-insensitive)
    if (upper == 'AND')
      return new Token(TokenType.OP_AND, value, position);
    if (upper == 'OR')
      return new Token(TokenType.OP_OR, value, position);
    if (upper == 'NOT')
      return new Token(TokenType.OP_NOT, value, position);
    if (upper == 'NULL')
      return new Token(TokenType.NULL_VALUE, value, position);
    if (upper == 'TRUE' || upper == 'FALSE')
      return new Token(TokenType.BOOLEAN_LITERAL, value, position);

    // Operators (case-insensitive)
    if (upper == 'IN')
      return new Token(TokenType.IIN, value, position);
    if (upper == 'LIKE')
      return new Token(TokenType.LK, value, position);
    if (upper == 'INCLUDES')
      return new Token(TokenType.INC, value, position);
    if (upper == 'EXCLUDES')
      return new Token(TokenType.EXC, value, position);

    // Handle "NOT IN" as two separate tokens (NOT + IN) - parser will combine

    // Datetime (YYYY-MM-DDTHH:mm:ss[.SSS][Z|±HH:mm])
    if (
      value.contains('T') &&
      (value.contains('Z') ||
      value.contains('+') ||
      (value.lastIndexOf('-') > 10))
    ) {
      // Contains T and timezone indicator
      if (
        Pattern.matches(
          '\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?(Z|[+\\-]\\d{2}:\\d{2})?',
          value
        )
      ) {
        return new Token(TokenType.DATETIME_LITERAL, value, position);
      }
    }

    // Date (YYYY-MM-DD)
    if (Pattern.matches('\\d{4}-\\d{2}-\\d{2}', value)) {
      return new Token(TokenType.DATE_LITERAL, value, position);
    }

    // Number (integer or decimal)
    if (Pattern.matches('[+\\-]?\\d+(\\.\\d+)?', value)) {
      return new Token(TokenType.NUMBER_LITERAL, value, position);
    }

    // Field path (alphanumeric with dots and underscores)
    if (Pattern.matches('[a-zA-Z0-9_.]+', value)) {
      return new Token(TokenType.FIELD, value, position);
    }

    return null;
  }

  // ========== PHASE 2: PARSING ==========

  public abstract class ParseNode {
  }

  public class FieldConditionNode extends ParseNode {
    public String fieldPath;
    public TokenType operator;
    public Object value; // Can be String, Number, Date, List<Object>, etc.
    public Boolean isNegated = false;

    public FieldConditionNode(
      String fieldPath,
      TokenType operator,
      Object value
    ) {
      this.fieldPath = fieldPath;
      this.operator = operator;
      this.value = value;
    }
  }

  public class LogicalNode extends ParseNode {
    public Boolean isOr; // true = OR, false = AND
    public Boolean isNegated = false;
    public List<ParseNode> children = new List<ParseNode>();

    public LogicalNode(Boolean isOr) {
      this.isOr = isOr;
    }
  }

  private List<Token> tokens;
  private Integer currentIndex;

  /**
   * Parse tokenized input into parse tree.
   */
  public ParseNode parse(String input) {
    tokens = tokenize(input);
    currentIndex = 0;
    return parseExpression();
  }

  private Token peek() {
    if (currentIndex < tokens.size()) {
      return tokens[currentIndex];
    }
    return tokens[tokens.size() - 1]; // EOF
  }

  private Token consume() {
    Token tok = peek();
    currentIndex++;
    return tok;
  }

  private Boolean match(TokenType type) {
    return peek().type == type;
  }

  private Token expect(TokenType type) {
    Token tok = peek();
    if (tok.type != type) {
      throw new ParseException(
        'Expected ' +
          type +
          ' at position ' +
          tok.position +
          ', got ' +
          tok.type
      );
    }
    return consume();
  }

  /**
   * Parse logical expression (handles AND/OR with precedence)
   * Grammar: orExpr
   */
  private ParseNode parseExpression() {
    return parseOrExpression();
  }

  /**
   * Parse OR expression (lower precedence)
   * Grammar: andExpr (OR andExpr)*
   */
  private ParseNode parseOrExpression() {
    ParseNode left = parseAndExpression();

    while (match(TokenType.OP_OR)) {
      consume(); // OR
      ParseNode right = parseAndExpression();

      // Combine into LogicalNode
      if (left instanceof LogicalNode && ((LogicalNode) left).isOr) {
        ((LogicalNode) left).children.add(right);
      } else {
        LogicalNode orNode = new LogicalNode(true);
        orNode.children.add(left);
        orNode.children.add(right);
        left = orNode;
      }
    }

    return left;
  }

  /**
   * Parse AND expression (higher precedence than OR)
   * Grammar: primary (AND primary)*
   */
  private ParseNode parseAndExpression() {
    ParseNode left = parsePrimary();

    while (match(TokenType.OP_AND)) {
      consume(); // AND
      ParseNode right = parsePrimary();

      // Combine into LogicalNode
      if (left instanceof LogicalNode && !((LogicalNode) left).isOr) {
        ((LogicalNode) left).children.add(right);
      } else {
        LogicalNode andNode = new LogicalNode(false);
        andNode.children.add(left);
        andNode.children.add(right);
        left = andNode;
      }
    }

    return left;
  }

  /**
   * Parse primary expression (field condition, NOT, or parenthesized expression)
   * Grammar: NOT primary | (expression) | fieldCondition
   */
  private ParseNode parsePrimary() {
    // Handle NOT
    if (match(TokenType.OP_NOT)) {
      consume();
      ParseNode node = parsePrimary();

      // Check if next token is IN (for "NOT IN" operator)
      if (match(TokenType.IIN)) {
        // This is "NOT IN" operator, rewind and parse as field condition
        currentIndex -= 1; // Put back NOT
        return parseFieldCondition();
      }

      // Regular NOT negation
      if (node instanceof LogicalNode) {
        ((LogicalNode) node).isNegated = true;
      } else if (node instanceof FieldConditionNode) {
        ((FieldConditionNode) node).isNegated = true;
      }
      return node;
    }

    // Handle parenthesized expression
    if (match(TokenType.LPAREN)) {
      consume();
      ParseNode node = parseExpression();
      expect(TokenType.RPAREN);
      return node;
    }

    // Handle field condition
    return parseFieldCondition();
  }

  /**
   * Parse field condition (field operator value)
   * Grammar: FIELD operator value
   */
  private ParseNode parseFieldCondition() {
    // Get field name
    Token fieldToken = expect(TokenType.FIELD);
    String fieldPath = fieldToken.value;

    // Handle "NOT IN" as special case
    Boolean isNotIn = false;
    if (match(TokenType.OP_NOT)) {
      consume();
      expect(TokenType.IIN);
      isNotIn = true;
    }

    // Get operator
    Token opToken = peek();
    if (!isOperator(opToken.type) && !isNotIn) {
      throw new ParseException(
        'Expected operator at position ' +
          opToken.position +
          ', got ' +
          opToken.type
      );
    }

    TokenType operator = isNotIn ? TokenType.NIN : opToken.type;
    if (!isNotIn) {
      consume();
    }

    // Get value (can be literal or list)
    Object value = parseValue();

    return new FieldConditionNode(fieldPath, operator, value);
  }

  private Boolean isOperator(TokenType type) {
    return type == TokenType.EQ ||
      type == TokenType.NE ||
      type == TokenType.LT ||
      type == TokenType.GT ||
      type == TokenType.LE ||
      type == TokenType.GE ||
      type == TokenType.LK ||
      type == TokenType.IIN ||
      type == TokenType.NIN ||
      type == TokenType.INC ||
      type == TokenType.EXC;
  }

  /**
   * Parse value (literal or list of literals)
   * Grammar: literal | (literal, literal, ...)
   */
  private Object parseValue() {
    // Handle list values (for IN operator)
    if (match(TokenType.LPAREN)) {
      consume();
      List<Object> values = new List<Object>();

      values.add(parseLiteral());

      while (match(TokenType.COMMA)) {
        consume();
        values.add(parseLiteral());
      }

      expect(TokenType.RPAREN);
      return values;
    }

    return parseLiteral();
  }

  /**
   * Parse literal value
   * Grammar: STRING | NUMBER | DATE | DATETIME | BOOLEAN | NULL
   */
  private Object parseLiteral() {
    Token tok = peek();

    if (tok.type == TokenType.STRING_LITERAL) {
      consume();
      return tok.value;
    }
    if (tok.type == TokenType.NUMBER_LITERAL) {
      consume();
      // Return as string, will be converted in toCondition()
      return tok.value;
    }
    if (tok.type == TokenType.DATE_LITERAL) {
      consume();
      return tok.value;
    }
    if (tok.type == TokenType.DATETIME_LITERAL) {
      consume();
      return tok.value;
    }
    if (tok.type == TokenType.BOOLEAN_LITERAL) {
      consume();
      return Boolean.valueOf(tok.value);
    }
    if (tok.type == TokenType.NULL_VALUE) {
      consume();
      return null;
    }

    throw new ParseException(
      'Expected literal at position ' + tok.position + ', got ' + tok.type
    );
  }

  // ========== PHASE 3: CONVERSION TO ICondition ==========

  /**
   * Convert parse tree to ICondition using Filtering and Core instances.
   * This is where schema dependencies are injected.
   */
  public ICondition toCondition(
    ParseNode tree,
    Filtering filtering,
    Core core
  ) {
    if (tree instanceof FieldConditionNode) {
      return convertFieldCondition((FieldConditionNode) tree, filtering, core);
    } else if (tree instanceof LogicalNode) {
      return convertLogicalNode((LogicalNode) tree, filtering, core);
    }
    throw new ParseException('Unknown parse node type');
  }

  private ICondition convertFieldCondition(
    FieldConditionNode node,
    Filtering filtering,
    Core core
  ) {
    // Convert TokenType operator to Enums.Comparator
    Enums.Comparator op = null;
    if (node.operator == TokenType.EQ)
      op = Enums.Comparator.EQ;
    else if (node.operator == TokenType.NE)
      op = Enums.Comparator.NE;
    else if (node.operator == TokenType.LT)
      op = Enums.Comparator.LT;
    else if (node.operator == TokenType.GT)
      op = Enums.Comparator.GT;
    else if (node.operator == TokenType.LE)
      op = Enums.Comparator.LE;
    else if (node.operator == TokenType.GE)
      op = Enums.Comparator.GE;
    else if (node.operator == TokenType.LK)
      op = Enums.Comparator.LK;
    else if (node.operator == TokenType.IIN)
      op = Enums.Comparator.IIN;
    else if (node.operator == TokenType.NIN)
      op = Enums.Comparator.NIN;
    else if (node.operator == TokenType.INC)
      op = Enums.Comparator.INC;
    else if (node.operator == TokenType.EXC)
      op = Enums.Comparator.EXC;

    // Convert value (handle datetimes, dates, numbers, lists)
    Object convertedValue = convertValue(node.value, core);

    // Use factory method instead of constructor (constructor is private)
    ICondition fc = filtering.fieldCondition(
      op,
      node.fieldPath,
      convertedValue,
      node.isNegated
    );

    return fc;
  }

  private ICondition convertLogicalNode(
    LogicalNode node,
    Filtering filtering,
    Core core
  ) {
    List<ICondition> children = new List<ICondition>();
    for (ParseNode child : node.children) {
      children.add(toCondition(child, filtering, core));
    }

    // Use factory method
    ICondition lc = filtering.logicalCondition(
      node.isOr,
      node.isNegated,
      children
    );

    return lc;
  }

  private Object convertValue(Object value, Core core) {
    if (value instanceof List<Object>) {
      // Convert list of values to strongly-typed list
      List<Object> values = (List<Object>) value;
      List<Object> converted = new List<Object>();
      String typeName = null;

      for (Object v : values) {
        Object convertedItem = convertValue(v, core);
        converted.add(convertedItem);

        // Determine type name from first non-null value
        if (typeName == null && convertedItem != null) {
          Typing.SoapyValue soapy = Typing.getSoapyValue(convertedItem, null);
          typeName = soapy.typeName();
        }
      }

      // Use JSON deserialization to convert List<Object> to strongly-typed List<T>
      // This is required for IN/NOT IN operators to work with Typing.Comparison
      if (typeName != null) {
        Object retCast = JSON.deserialize(
          JSON.serialize(converted),
          core.injector().getType('List<' + typeName + '>')
        );
        return retCast;
      }

      return converted;
    }

    if (value instanceof String) {
      String strValue = (String) value;

      // Check if it's a datetime
      if (
        Pattern.matches(
          '\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?(Z|[+\\-]\\d{2}:\\d{2})?',
          strValue
        )
      ) {
        return parseDatetime(strValue);
      }

      // Check if it's a date
      if (Pattern.matches('\\d{4}-\\d{2}-\\d{2}', strValue)) {
        return Date.valueOf(strValue);
      }

      // Check if it's a number
      if (Pattern.matches('[+\\-]?\\d+\\.\\d+', strValue)) {
        return Decimal.valueOf(strValue);
      }
      if (Pattern.matches('[+\\-]?\\d+', strValue)) {
        return Integer.valueOf(strValue);
      }

      // It's a string
      return strValue;
    }

    return value;
  }

  /**
   * Parse datetime string with timezone support.
   * Handles: YYYY-MM-DDTHH:mm:ss[.SSS][Z|±HH:mm]
   */
  private Datetime parseDatetime(String dtString) {
    Matcher mat = Pattern.compile(
        '(\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2})(\\.\\d{3})?(Z|[+\\-]\\d{2}:\\d{2})?'
      )
      .matcher(dtString);

    if (mat.matches()) {
      Datetime dt = Datetime.valueOfGmt(mat.group(1).replace('T', ' '));
      Long ms = dt.getTime();

      // Add milliseconds if present
      if (mat.group(2) != null) {
        ms += Integer.valueOf(mat.group(2).replace('.', ''));
      }

      // Handle timezone
      if (mat.group(3) != null) {
        if (mat.group(3) == 'Z') {
          // UTC - adjust from user timezone
          ms -= UserInfo.getTimeZone().getOffset(dt);
        } else {
          // Timezone offset ±HH:mm
          List<String> parts = mat.group(3).split(':');
          Integer hours = Integer.valueOf(parts[0]);
          Integer minutes = Integer.valueOf(parts[1]);
          Integer totalMinutes = hours * 60 + (hours < 0 ? -minutes : minutes);
          ms -= (totalMinutes * 60 * 1000);
        }
      }

      return Datetime.newInstance(ms);
    }

    throw new ParseException('Invalid datetime format: ' + dtString);
  }
}
