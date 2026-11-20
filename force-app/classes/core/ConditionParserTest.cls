@isTest
private class ConditionParserTest {
  static Core core = new Core();

  // ========== TOKENIZATION TESTS ==========

  @isTest
  static void test_tokenize_simple_condition() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize('Name = \'Acme\'');

    System.assertEquals(4, tokens.size()); // FIELD, EQ, STRING, EOF
    System.assertEquals(ConditionParser.TokenType.FIELD, tokens[0].type);
    System.assertEquals('Name', tokens[0].value);
    System.assertEquals(ConditionParser.TokenType.EQ, tokens[1].type);
    System.assertEquals(
      ConditionParser.TokenType.STRING_LITERAL,
      tokens[2].type
    );
    System.assertEquals('Acme', tokens[2].value);
    System.assertEquals(ConditionParser.TokenType.EOF, tokens[3].type);
  }

  @isTest
  static void test_tokenize_datetime_with_Z() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'CreatedDate >= 2023-12-25T10:30:00Z'
    );

    System.assertEquals(4, tokens.size());
    System.assertEquals(ConditionParser.TokenType.FIELD, tokens[0].type);
    System.assertEquals('CreatedDate', tokens[0].value);
    System.assertEquals(ConditionParser.TokenType.GE, tokens[1].type);
    System.assertEquals(
      ConditionParser.TokenType.DATETIME_VALUE,
      tokens[2].type
    );
    System.assertEquals('2023-12-25T10:30:00Z', tokens[2].value);
  }

  @isTest
  static void test_tokenize_datetime_with_milliseconds() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'CreatedDate >= 2023-12-25T10:30:00.123Z'
    );

    System.assertEquals(4, tokens.size());
    System.assertEquals(
      ConditionParser.TokenType.DATETIME_VALUE,
      tokens[2].type
    );
    System.assertEquals('2023-12-25T10:30:00.123Z', tokens[2].value);
  }

  @isTest
  static void test_tokenize_datetime_with_timezone() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'CreatedDate >= 2023-12-25T10:30:00+05:30'
    );

    System.assertEquals(4, tokens.size());
    System.assertEquals(
      ConditionParser.TokenType.DATETIME_VALUE,
      tokens[2].type
    );
    System.assertEquals('2023-12-25T10:30:00+05:30', tokens[2].value);
  }

  @isTest
  static void test_tokenize_numbers() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens1 = parser.tokenize('Amount = 100');
    System.assertEquals(
      ConditionParser.TokenType.NUMBER_LITERAL,
      tokens1[2].type
    );
    System.assertEquals('100', tokens1[2].value);

    List<ConditionParser.Token> tokens2 = parser.tokenize('Price = 99.99');
    System.assertEquals(
      ConditionParser.TokenType.NUMBER_LITERAL,
      tokens2[2].type
    );
    System.assertEquals('99.99', tokens2[2].value);
  }

  @isTest
  static void test_tokenize_boolean() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens = parser.tokenize('IsActive = TRUE');
    System.assertEquals(
      ConditionParser.TokenType.BOOLEAN_LITERAL,
      tokens[2].type
    );
    System.assertEquals('TRUE', tokens[2].value);
  }

  @isTest
  static void test_tokenize_null() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens = parser.tokenize('Value = NULL');
    System.assertEquals(ConditionParser.TokenType.NULL_VALUE, tokens[2].type);
  }

  @isTest
  static void test_tokenize_operators() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens1 = parser.tokenize('Amount != 100');
    System.assertEquals(ConditionParser.TokenType.NE, tokens1[1].type);

    List<ConditionParser.Token> tokens2 = parser.tokenize('Amount < 100');
    System.assertEquals(ConditionParser.TokenType.LT, tokens2[1].type);

    List<ConditionParser.Token> tokens3 = parser.tokenize('Amount <= 100');
    System.assertEquals(ConditionParser.TokenType.LE, tokens3[1].type);

    List<ConditionParser.Token> tokens4 = parser.tokenize(
      'Name LIKE \'%Acme%\''
    );
    System.assertEquals(ConditionParser.TokenType.LK, tokens4[1].type);

    List<ConditionParser.Token> tokens5 = parser.tokenize(
      'Status IN (\'Open\', \'Pending\')'
    );
    System.assertEquals(ConditionParser.TokenType.IIN, tokens5[1].type);
  }

  @isTest
  static void test_tokenize_logical_keywords() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens = parser.tokenize(
      'Name = \'Acme\' AND Status = \'Open\''
    );
    Boolean foundAnd = false;
    for (ConditionParser.Token tok : tokens) {
      if (tok.type == ConditionParser.TokenType.OP_AND) {
        foundAnd = true;
      }
    }
    System.assert(foundAnd, 'Should find AND token');
  }

  @isTest
  static void test_tokenize_parentheses() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens = parser.tokenize('(Name = \'Acme\')');
    System.assertEquals(ConditionParser.TokenType.LPAREN, tokens[0].type);
    System.assertEquals(ConditionParser.TokenType.RPAREN, tokens[4].type);
  }

  @isTest
  static void test_tokenize_list_values() {
    ConditionParser parser = new ConditionParser();

    List<ConditionParser.Token> tokens = parser.tokenize(
      'Status IN (\'Open\', \'Pending\')'
    );
    Integer commas = 0;
    for (ConditionParser.Token tok : tokens) {
      if (tok.type == ConditionParser.TokenType.COMMA)
        commas++;
    }
    System.assertEquals(1, commas, 'Should find 1 comma in list');
  }

  // ========== PARSING TESTS ==========

  @isTest
  static void test_parse_simple_condition() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('Name = \'Acme\'');

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals('Name', node.fieldPath);
    System.assertEquals(ConditionParser.TokenType.EQ, node.operator);
    System.assertEquals('Acme', node.value);
  }

  @isTest
  static void test_parse_AND_condition() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Name = \'Acme\' AND Status = \'Open\''
    );

    System.assert(tree instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode node = (ConditionParser.LogicalNode) tree;
    System.assertEquals(false, node.isOr);
    System.assertEquals(2, node.children.size());
  }

  @isTest
  static void test_parse_OR_condition() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Status = \'Open\' OR Status = \'Pending\''
    );

    System.assert(tree instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode node = (ConditionParser.LogicalNode) tree;
    System.assertEquals(true, node.isOr);
    System.assertEquals(2, node.children.size());
  }

  @isTest
  static void test_parse_NOT_condition() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('NOT (Status = \'Closed\')');

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(true, node.isNegated);
  }

  @isTest
  static void test_parse_NOT_IN_operator() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Status NOT IN (\'Closed\', \'Cancelled\')'
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.NIN, node.operator);
  }

  @isTest
  static void test_parse_parenthesized_condition() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('(Name = \'Acme\')');

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals('Name', node.fieldPath);
  }

  @isTest
  static void test_parse_complex_nested_condition() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      '(Name = \'Acme\' OR Name = \'Globex\') AND Status = \'Open\''
    );

    System.assert(tree instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode node = (ConditionParser.LogicalNode) tree;
    System.assertEquals(false, node.isOr); // Top level is AND
    System.assertEquals(2, node.children.size());

    // First child should be OR node
    System.assert(node.children[0] instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode orNode = (ConditionParser.LogicalNode) node.children[0];
    System.assertEquals(true, orNode.isOr);
  }

  @isTest
  static void test_parse_list_value() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Status IN (\'Open\', \'Pending\', \'Closed\')'
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.IIN, node.operator);
    System.assert(node.value instanceof List<Object>);
    List<Object> values = (List<Object>) node.value;
    System.assertEquals(3, values.size());
  }

  @isTest
  static void test_parse_date() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('CreatedDate = 2023-12-25');

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(Date.newInstance(2023, 12, 25), node.value);
  }

  @isTest
  static void test_parse_datetime_with_Z() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'CreatedDate >= 2023-12-25T10:30:00Z'
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.GE, node.operator);
    System.assertEquals(Datetime.newInstanceGmt(2023, 12, 25, 10, 30, 0), node.value);
  }

  // ========== CONVERSION TO ICondition TESTS ==========

  @isTest
  static void test_toCondition_simple() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('Name = \'Acme\'');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    System.assert(cond != null);
    String soql = cond.toSoql();
    System.assert(soql.contains('Name'), 'SOQL should contain Name field');
    System.assert(soql.contains('Acme'), 'SOQL should contain Acme value');
  }

  @isTest
  static void test_toCondition_AND() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Name = \'Acme\' AND Industry = \'Technology\''
    );
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    String soql = cond.toSoql();
    System.assert(soql.contains('AND'), 'SOQL should contain AND');
    System.assert(soql.contains('Name'), 'SOQL should contain Name');
    System.assert(soql.contains('Industry'), 'SOQL should contain Industry');
  }

  @isTest
  static void test_toCondition_datetime_with_Z() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'CreatedDate >= 2023-12-25T10:30:00Z'
    );
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    String soql = cond.toSoql();
    System.assert(
      soql.contains('CreatedDate'),
      'SOQL should contain CreatedDate'
    );
    System.assert(soql.contains('>='), 'SOQL should contain >= operator');
  }

  @isTest
  static void test_toCondition_with_realize() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('Name = \'Acme\'');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);

    // Realize with Account SObjectType
    cond.realize(Account.SObjectType);

    // Should not throw exception
    String soql = cond.toSoql();
    System.assert(soql != null);
  }

  // ========== INTEGRATION TESTS WITH IModel ==========

  @isTest
  static void test_IModel_parseCondition() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      'Name = \'Acme\' AND Industry = \'Technology\''
    );

    // Should be auto-realized
    String soql = cond.toSoql();
    System.assert(soql.contains('Name'));
    System.assert(soql.contains('Industry'));
    System.assert(soql.contains('AND'));
  }

  @isTest
  static void test_IModel_parseCondition_datetime_bug_fix() {
    IModel accountModel = core.model(Account.SObjectType);

    // This used to fail before the bug fix
    ICondition cond = accountModel.parseCondition(
      'CreatedDate >= 2023-12-25T10:30:00Z'
    );

    // Should be auto-realized and work immediately
    String soql = cond.toSoql();
    System.assert(soql.contains('CreatedDate'));
    System.assert(soql.contains('>='));
  }

  @isTest
  static void test_IModel_parseCondition_complex() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      '(Name = \'Acme\' OR Name = \'Globex\') AND CreatedDate >= 2023-01-01T00:00:00Z'
    );

    String soql = cond.toSoql();
    System.assert(soql.contains('Name'));
    System.assert(soql.contains('CreatedDate'));
    System.assert(soql.contains('OR'));
    System.assert(soql.contains('AND'));
  }

  // ========== ERROR HANDLING TESTS ==========

  @isTest
  static void test_parse_error_unexpected_token() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.parse('Name = ');
      System.assert(false, 'Should throw ParseException');
    } catch (ConditionParser.ParseException e) {
      System.assert(
        e.getMessage().contains('Expected literal'),
        'Error message should indicate missing literal'
      );
    }
  }

  @isTest
  static void test_parse_error_missing_operator() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.parse('Name \'Acme\'');
      System.assert(false, 'Should throw ParseException');
    } catch (ConditionParser.ParseException e) {
      System.assert(
        e.getMessage().contains('operator'),
        'Error message should mention operator'
      );
    }
  }

  @isTest
  static void test_parse_error_unmatched_parenthesis() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.parse('(Name = \'Acme\'');
      System.assert(false, 'Should throw ParseException');
    } catch (ConditionParser.ParseException e) {
      System.assert(
        e.getMessage().contains('RPAREN'),
        'Error message should mention missing )'
      );
    }
  }

  // ========== VALUE CONVERSION TESTS ==========

  @isTest
  static void test_convertValue_integer() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('NumberOfEmployees = 100');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    // Value should be converted to Integer
    String soql = cond.toSoql();
    System.assert(soql.contains('100'));
  }

  @isTest
  static void test_convertValue_decimal() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('AnnualRevenue = 99.99');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    String soql = cond.toSoql();
    System.assert(soql.contains('99.99'));
  }

  @isTest
  static void test_convertValue_date() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('CreatedDate = 2023-12-25');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    String soql = cond.toSoql();
    System.assert(soql.contains('2023-12-25'));
  }

  @isTest
  static void test_convertValue_boolean() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('IsDeleted = TRUE');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    String soql = cond.toSoql();
    System.assert(soql.contains('TRUE') || soql.contains('true'));
  }

  @isTest
  static void test_convertValue_null() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('Description = NULL');
    ICondition cond = parser.toCondition(tree, core.filtering(), core);
    cond.realize(Account.SObjectType);

    String soql = cond.toSoql();
    System.assert(soql.contains('NULL') || soql.contains('null'));
  }

  // ========== MISSING OPERATOR TESTS ==========

  @isTest
  static void test_operator_GT() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('AnnualRevenue > 1000000');

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.GT, node.operator);
  }

  @isTest
  static void test_operator_INCLUDES() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Industry INCLUDES \'Technology\''
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.INC, node.operator);
  }

  @isTest
  static void test_operator_EXCLUDES() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Industry EXCLUDES \'Retail\''
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.EXC, node.operator);
  }

  // ========== TOKENIZATION EDGE CASES ==========

  @isTest
  static void test_tokenize_escaped_quotes() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'Name = \'O\'\'Brien\''
    );

    System.assertEquals(
      ConditionParser.TokenType.STRING_LITERAL,
      tokens[2].type
    );
    System.assertEquals('O\'Brien', tokens[2].value);
  }

  @isTest
  static void test_tokenize_empty_string() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize('Name = \'\'');

    System.assertEquals(
      ConditionParser.TokenType.STRING_LITERAL,
      tokens[2].type
    );
    System.assertEquals('', tokens[2].value);
  }

  @isTest
  static void test_tokenize_relationship_field() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'Owner.Name = \'John\''
    );

    System.assertEquals(ConditionParser.TokenType.FIELD, tokens[0].type);
    System.assertEquals('Owner.Name', tokens[0].value);
  }

  @isTest
  static void test_tokenize_custom_field() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'Custom_Field__c = \'Test\''
    );

    System.assertEquals(ConditionParser.TokenType.FIELD, tokens[0].type);
    System.assertEquals('Custom_Field__c', tokens[0].value);
  }

  @isTest
  static void test_tokenize_negative_number() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize('Amount = -100');

    System.assertEquals(
      ConditionParser.TokenType.NUMBER_LITERAL,
      tokens[2].type
    );
    System.assertEquals('-100', tokens[2].value);
  }

  @isTest
  static void test_tokenize_case_insensitive_keywords() {
    ConditionParser parser = new ConditionParser();

    // Test lowercase
    List<ConditionParser.Token> tokens1 = parser.tokenize(
      'Name = \'Test\' and Status = \'Open\''
    );
    Boolean foundAnd1 = false;
    for (ConditionParser.Token tok : tokens1) {
      if (tok.type == ConditionParser.TokenType.OP_AND)
        foundAnd1 = true;
    }
    System.assert(foundAnd1, 'Should recognize lowercase AND');

    // Test mixed case
    List<ConditionParser.Token> tokens2 = parser.tokenize('IsActive = true');
    System.assertEquals(
      ConditionParser.TokenType.BOOLEAN_LITERAL,
      tokens2[2].type
    );
  }

  // ========== PARSING EDGE CASES ==========

  @isTest
  static void test_parse_deep_nesting() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse('((((Name = \'Test\'))))');

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals('Name', node.fieldPath);
  }

  @isTest
  static void test_parse_operator_precedence() {
    // AND has higher precedence than OR
    // A OR B AND C should parse as A OR (B AND C)
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Name = \'A\' OR Industry = \'B\' AND Type = \'C\''
    );

    System.assert(tree instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode orNode = (ConditionParser.LogicalNode) tree;
    System.assertEquals(true, orNode.isOr, 'Top level should be OR');
    System.assertEquals(2, orNode.children.size());

    // Second child should be AND node
    System.assert(orNode.children[1] instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode andNode = (ConditionParser.LogicalNode) orNode.children[1];
    System.assertEquals(false, andNode.isOr, 'Right side should be AND');
  }

  @isTest
  static void test_parse_long_AND_chain() {
    ConditionParser parser = new ConditionParser();
    String condition = 'Field1 = \'A\' AND Field2 = \'B\' AND Field3 = \'C\' AND Field4 = \'D\' AND Field5 = \'E\'';
    ConditionParser.ParseNode tree = parser.parse(condition);

    System.assert(tree instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode node = (ConditionParser.LogicalNode) tree;
    System.assertEquals(false, node.isOr);
    System.assertEquals(5, node.children.size());
  }

  @isTest
  static void test_parse_multiple_NOT() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'NOT (Name = \'Test\') AND NOT (Status = \'Closed\')'
    );

    System.assert(tree instanceof ConditionParser.LogicalNode);
    ConditionParser.LogicalNode andNode = (ConditionParser.LogicalNode) tree;
    System.assertEquals(2, andNode.children.size());

    // Both children should be negated
    ConditionParser.FieldConditionNode child1 = (ConditionParser.FieldConditionNode) andNode.children[0];
    ConditionParser.FieldConditionNode child2 = (ConditionParser.FieldConditionNode) andNode.children[1];
    System.assertEquals(true, child1.isNegated);
    System.assertEquals(true, child2.isNegated);
  }

  // ========== DATETIME EDGE CASES ==========

  @isTest
  static void test_datetime_negative_timezone() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'CreatedDate >= 2023-12-25T10:30:00-08:00'
    );

    System.assertEquals(
      ConditionParser.TokenType.DATETIME_VALUE,
      tokens[2].type
    );
    System.assertEquals('2023-12-25T10:30:00-08:00', tokens[2].value);
  }

  @isTest
  static void test_datetime_midnight() {
    ConditionParser parser = new ConditionParser();
    List<ConditionParser.Token> tokens = parser.tokenize(
      'CreatedDate >= 2023-12-25T00:00:00Z'
    );

    System.assertEquals(
      ConditionParser.TokenType.DATETIME_VALUE,
      tokens[2].type
    );
    System.assertEquals('2023-12-25T00:00:00Z', tokens[2].value);
  }

  // ========== ERROR HANDLING TESTS ==========

  @isTest
  static void test_error_empty_input() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.parse('');
      System.assert(false, 'Should throw ParseException for empty input');
    } catch (ConditionParser.ParseException e) {
      System.assert(e.getMessage() != null);
    }
  }

  @isTest
  static void test_error_unclosed_quote() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.tokenize('Name = \'Unclosed');
      System.assert(false, 'Text without its closing quote was read to the end');
    } catch (ConditionParser.ParseException e) {
      System.assertEquals('The text that starts at position 7 has no closing quote', e.getMessage());
    }
  }

  @isTest
  static void test_error_invalid_field_on_realize() {
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'NonExistentField__c = \'Test\''
    );
    ICondition cond = parser.toCondition(tree, core.filtering(), core);

    try {
      cond.realize(Account.SObjectType);
      System.assert(false, 'Should throw exception for invalid field');
    } catch (Exception e) {
      System.assert(e.getMessage().contains('NonExistentField__c'));
    }
  }

  @isTest
  static void test_error_missing_value() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.parse('Name =');
      System.assert(false, 'Should throw ParseException for missing value');
    } catch (ConditionParser.ParseException e) {
      System.assert(e.getMessage().contains('literal'));
    }
  }

  @isTest
  static void test_error_invalid_operator() {
    ConditionParser parser = new ConditionParser();

    try {
      parser.parse('Name <> \'Test\''); // <> not supported, use !=
      System.assert(false, 'Should throw ParseException for invalid operator');
    } catch (ConditionParser.ParseException e) {
      System.assert(true);
    }
  }

  // ========== EVALUATE() FUNCTIONALITY TESTS ==========

  @isTest
  static void test_evaluate_simple_condition() {
    Account acc = new Account(
      Name = 'Acme Corporation',
      Industry = 'Technology'
    );

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      'Name = \'Acme Corporation\''
    );

    System.assert(cond.evaluate(acc), 'Should match account name');
  }

  @isTest
  static void test_evaluate_AND_condition() {
    Account acc = new Account(Name = 'Acme', Industry = 'Technology');

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      'Name = \'Acme\' AND Industry = \'Technology\''
    );

    System.assert(cond.evaluate(acc), 'Should match both conditions');
  }

  @isTest
  static void test_evaluate_OR_condition() {
    Account acc = new Account(Name = 'Acme', Industry = 'Technology');

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      'Name = \'Globex\' OR Industry = \'Technology\''
    );

    System.assert(cond.evaluate(acc), 'Should match on Industry');
  }

  @isTest
  static void test_evaluate_NOT_condition() {
    Account acc = new Account(Name = 'Acme', Industry = 'Technology');

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      'NOT (Industry = \'Retail\')'
    );

    System.assert(cond.evaluate(acc), 'Should not match Retail');
  }

  @isTest
  static void test_evaluate_numeric_comparison() {
    Account acc = new Account(NumberOfEmployees = 500);

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond1 = accountModel.parseCondition('NumberOfEmployees > 100');
    ICondition cond2 = accountModel.parseCondition('NumberOfEmployees <= 1000');
    ICondition cond3 = accountModel.parseCondition('NumberOfEmployees = 500');

    System.assert(cond1.evaluate(acc), 'Should be greater than 100');
    System.assert(cond2.evaluate(acc), 'Should be less than or equal to 1000');
    System.assert(cond3.evaluate(acc), 'Should equal 500');
  }

  @isTest
  static void test_evaluate_null_value() {
    Account acc = new Account(Name = 'Test', Description = null);

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition('Description = NULL');

    System.assert(cond.evaluate(acc), 'Should match null description');
  }

  @isTest
  static void test_evaluate_IN_operator() {
    // Test parsing of IN operator with list values
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Industry IN (\'Technology\', \'Finance\', \'Healthcare\')'
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.IIN, node.operator);
    System.assert(node.value instanceof List<Object>);
    List<Object> values = (List<Object>) node.value;
    System.assertEquals(3, values.size());
  }

  @isTest
  static void test_evaluate_NOT_IN_operator() {
    // Test parsing of NOT IN operator with list values
    ConditionParser parser = new ConditionParser();
    ConditionParser.ParseNode tree = parser.parse(
      'Industry NOT IN (\'Retail\', \'Manufacturing\')'
    );

    System.assert(tree instanceof ConditionParser.FieldConditionNode);
    ConditionParser.FieldConditionNode node = (ConditionParser.FieldConditionNode) tree;
    System.assertEquals(ConditionParser.TokenType.NIN, node.operator);
    System.assert(node.value instanceof List<Object>);
    List<Object> values = (List<Object>) node.value;
    System.assertEquals(2, values.size());
  }

  @isTest
  static void test_evaluate_complex_nested() {
    Account acc = new Account(
      Name = 'Acme',
      Industry = 'Technology',
      NumberOfEmployees = 500
    );

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      '(Name = \'Acme\' OR Name = \'Globex\') AND Industry = \'Technology\' AND NumberOfEmployees > 100'
    );

    System.assert(cond.evaluate(acc), 'Should match complex condition');
  }

  // ========== CLONE AND PREPEND TESTS ==========

  @isTest
  static void test_clone_shallow() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition original = accountModel.parseCondition(
      'Name = \'Acme\' AND Industry = \'Technology\''
    );

    ICondition cloned = original.clone(false);

    System.assert(cloned != null, 'Clone should not be null');
    System.assertEquals(
      original.toSoql(),
      cloned.toSoql(),
      'Clone should produce same SOQL'
    );
  }

  @isTest
  static void test_clone_deep() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition original = accountModel.parseCondition(
      'Name = \'Acme\' AND Industry = \'Technology\''
    );

    ICondition cloned = original.clone(true);

    System.assert(cloned != null, 'Deep clone should not be null');
    System.assertEquals(
      original.toSoql(),
      cloned.toSoql(),
      'Deep clone should produce same SOQL'
    );
  }

  // ========== REAL-WORLD SCENARIO TESTS ==========

  @isTest
  static void test_realistic_account_query() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      '(Industry = \'Technology\' OR Industry = \'Finance\') AND ' +
        'NumberOfEmployees > 100 AND ' +
        'CreatedDate >= 2023-01-01T00:00:00Z'
    );

    String soql = cond.toSoql();
    System.assert(soql.contains('Industry'));
    System.assert(soql.contains('NumberOfEmployees'));
    System.assert(soql.contains('CreatedDate'));
    System.assert(soql.contains('OR'));
    System.assert(soql.contains('AND'));
  }

  @isTest
  static void test_realistic_filtering_scenario() {
    // Create test accounts (use direct field comparisons instead of IN for evaluate())
    Account acc1 = new Account(
      Name = 'TechCorp',
      Industry = 'Technology',
      NumberOfEmployees = 500
    );
    Account acc2 = new Account(
      Name = 'RetailCo',
      Industry = 'Retail',
      NumberOfEmployees = 50
    );
    Account acc3 = new Account(
      Name = 'FinanceCorp',
      Industry = 'Finance',
      NumberOfEmployees = 200
    );

    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      '(Industry = \'Technology\' OR Industry = \'Finance\') AND NumberOfEmployees >= 100'
    );

    System.assert(cond.evaluate(acc1), 'TechCorp should match');
    System.assert(
      !cond.evaluate(acc2),
      'RetailCo should not match (wrong industry)'
    );
    System.assert(cond.evaluate(acc3), 'FinanceCorp should match');
  }

  @isTest
  static void test_multiple_conditions_with_different_operators() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition cond = accountModel.parseCondition(
      'Name LIKE \'%Corp%\' AND ' +
        'NumberOfEmployees > 100 AND ' +
        'NumberOfEmployees <= 1000 AND ' +
        'Industry != \'Retail\''
    );

    Account acc1 = new Account(
      Name = 'TechCorp',
      Industry = 'Technology',
      NumberOfEmployees = 500
    );
    Account acc2 = new Account(
      Name = 'Big Retail Corp',
      Industry = 'Retail',
      NumberOfEmployees = 500
    );

    System.assert(cond.evaluate(acc1), 'TechCorp should match all conditions');
    System.assert(
      !cond.evaluate(acc2),
      'Retail Corp should not match (excluded industry)'
    );
  }

  @isTest
  static void aSubqueryInTextIsRefusedWithAMessageThatSaysWhatToDo() {
    IModel accountModel = core.model(Account.SObjectType);
    Map<String, Integer> positionByText = new Map<String, Integer>{
      'Id IN (SELECT AccountId FROM Contact)' => 7,
      'Id NOT IN (select AccountId from Contact)' => 11,
      'Name = \'Acme\' AND Id IN ( SELECT AccountId FROM Contact WHERE MailingCity = \'Seattle\')' => 26
    };

    for (String text : positionByText.keySet()) {
      try {
        accountModel.parseCondition(text);
        System.assert(false, 'A subquery was parsed: ' + text);
      } catch (ConditionParser.ParseException e) {
        System.assert(e.getMessage().contains('build a semi-join'), e.getMessage());
        System.assert(e.getMessage().contains('at position ' + positionByText.get(text) + ' '), e.getMessage());
      }
    }

    // A list of values is still a list, whatever the values say.
    ICondition listed = accountModel.parseCondition('Name IN (\'SELECT\', \'Acme\')');
    System.assert(listed.evaluate(new Account(Name = 'select')));
  }

  @isTest
  static void textAfterACompleteConditionIsAnErrorThatGivesItsPosition() {
    IModel accountModel = core.model(Account.SObjectType);
    Map<String, String> unexpectedByText = new Map<String, String>{
      'Name = \'x\' ORDER BY Name' => 'Unexpected ORDER at position 11',
      'Name = \'x\' LIMIT 5' => 'Unexpected LIMIT at position 11',
      'Name = \'x\' Industry = \'y\'' => 'Unexpected Industry at position 11',
      'Name = \'x\')' => 'Unexpected ) at position 10',
      '(Name = \'x\') 5' => 'Unexpected 5 at position 13',
      'Name IN (\'x\') \'y\'' => 'Unexpected y at position 14'
    };

    for (String text : unexpectedByText.keySet()) {
      try {
        accountModel.parseCondition(text);
        System.assert(false, 'Trailing text was dropped: ' + text);
      } catch (ConditionParser.ParseException e) {
        System.assert(e.getMessage().startsWith(unexpectedByText.get(text) + ':'), e.getMessage());
      }
    }

    // AND and OR do continue a condition
    System.assertEquals(
      '(Name = \'x\' AND Industry = \'y\')',
      accountModel.parseCondition('Name = \'x\' AND Industry = \'y\'').toSoql()
    );
  }

  @isTest
  static void noTextAtAllIsAnErrorNotACrash() {
    for (String text : new List<String>{ null, '', '   ' }) {
      try {
        core.model(Account.SObjectType).parseCondition(text);
        System.assert(false, 'Parsed nothing');
      } catch (ConditionParser.ParseException e) {
        System.assert(e.getMessage().startsWith('Expected FIELD at position'), e.getMessage());
      }
    }
  }

  @isTest
  static void dateLiteralsAreReadAsTheValuesOfDateFields() {
    IModel opportunities = core.model(Opportunity.SObjectType);
    List<String> written = new List<String>{
      'CloseDate = TODAY',
      'CloseDate >= LAST_N_DAYS:30',
      'CreatedDate != THIS_FISCAL_QUARTER',
      '(CloseDate < NEXT_N_FISCAL_YEARS:2 AND (NOT CreatedDate > N_WEEKS_AGO:0))',
      'CloseDate IN (THIS_WEEK, LAST_WEEK)',
      'CreatedDate NOT IN (YESTERDAY, NEXT_N_MONTHS:3)'
    };

    for (String text : written) {
      System.assertEquals(text, opportunities.parseCondition(text).toSoql(), 'read and written back the same');
    }
    System.assertEquals(
      'CloseDate = LAST_N_DAYS:30',
      opportunities.parseCondition('closedate = last_n_days:30').toSoql(),
      'in any case'
    );

    List<ConditionParser.Token> tokens = new ConditionParser().tokenize('CloseDate = LAST_N_DAYS:30');
    System.assertEquals(ConditionParser.TokenType.DATE_LITERAL, tokens[2].type);
    System.assertEquals('LAST_N_DAYS:30', tokens[2].value);

    for (String spaced : new List<String>{ 'CloseDate >= LAST_N_DAYS : 30', 'CloseDate >= last_n_days: 30', 'CloseDate >= LAST_N_DAYS :30' }) {
      System.assertEquals('CloseDate >= LAST_N_DAYS:30', opportunities.parseCondition(spaced).toSoql(), 'spaces around the colon, as SOQL takes them');
    }
    System.assertEquals(0, Database.query('SELECT Id FROM Opportunity WHERE CloseDate >= LAST_N_DAYS : 30').size());

    DateLiteral.fixedToday = Date.newInstance(2027, 6, 16);
    ICondition thisWeek = opportunities.parseCondition('CloseDate = THIS_WEEK');
    System.assert(((IFieldCondition) thisWeek).value() instanceof IDateLiteral, 'the value is the literal, not text');
    System.assert(thisWeek.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 16))));
    System.assert(!thisWeek.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 24))));

    ICondition lately = opportunities.parseCondition('CloseDate IN (YESTERDAY, TODAY)');
    System.assert(((IFieldCondition) lately).value() instanceof List<IDateLiteral>);
    System.assert(lately.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 15))));
    System.assert(!lately.evaluate(new Opportunity(CloseDate = Date.newInstance(2027, 6, 14))));
  }

  @isTest
  static void aDateLiteralIsRefusedWhereThePlatformRefusesIt() {
    IModel opportunities = core.model(Opportunity.SObjectType);

    // The platform ends the transaction for such a list, so it is refused here, with its position
    Map<String, Integer> positionByMixedList = new Map<String, Integer>{
      'CloseDate IN (TODAY, 2026-01-01)' => 21,
      'CloseDate IN (2026-01-01, TODAY)' => 26
    };
    for (String text : positionByMixedList.keySet()) {
      try {
        opportunities.parseCondition(text);
        System.assert(false, 'A mixed list was parsed: ' + text);
      } catch (ConditionParser.ParseException e) {
        System.assert(e.getMessage().startsWith('A list cannot mix date literals'), e.getMessage());
        System.assert(e.getMessage().endsWith('at position ' + positionByMixedList.get(text)), e.getMessage());
      }
    }

    for (String text : new List<String>{ 'Name = TODAY', 'Amount > LAST_N_DAYS:3', 'CloseDate LIKE TODAY' }) {
      try {
        opportunities.parseCondition(text);
        System.assert(false, 'Parsed ' + text);
      } catch (Typing.ValidationException e) {
        System.assert(e.getMessage().contains('date literal'), e.getMessage());
      }
    }

    // A literal that needs a number and has none is not a literal
    try {
      opportunities.parseCondition('CloseDate = LAST_N_DAYS');
      System.assert(false, 'Parsed a literal without its number');
    } catch (ConditionParser.ParseException e) {
      System.assertEquals('Expected literal at position 12, got FIELD', e.getMessage());
    }
  }

  @isTest
  static void aDatetimeIsReadInTheZoneItNamesWhateverTheUsersZone() {
    Map<String, String> writtenByText = new Map<String, String>{
      'CreatedDate > 2026-01-31T09:30:00Z' => 'CreatedDate > 2026-01-31T09:30:00.000Z',
      'CreatedDate > 2026-07-31T09:30:00.123Z' => 'CreatedDate > 2026-07-31T09:30:00.123Z',
      'CreatedDate > 2026-01-31T09:30:00+02:00' => 'CreatedDate > 2026-01-31T07:30:00.000Z',
      'CreatedDate > 2026-01-31T09:30:00-08:00' => 'CreatedDate > 2026-01-31T17:30:00.000Z',
      'CreatedDate > 2026-01-31T09:30:00-00:30' => 'CreatedDate > 2026-01-31T10:00:00.000Z',
      'CreatedDate > 2026-01-31T09:30:00+00:30' => 'CreatedDate > 2026-01-31T09:00:00.000Z',
      'CreatedDate > 2026-01-31T09:30:00-03:30' => 'CreatedDate > 2026-01-31T13:00:00.000Z',
      'CreatedDate > 2026-01-31T09:30:00+05:45' => 'CreatedDate > 2026-01-31T03:45:00.000Z'
    };

    for (String text : writtenByText.keySet()) {
      System.assertEquals(writtenByText.get(text), core.model(Account.SObjectType).parseCondition(text).toSoql());
    }

    User elsewhere = new User(
      ProfileId = UserInfo.getProfileId(),
      LastName = 'Elsewhere',
      Alias = 'elsewh',
      Email = 'elsewhere@parser.example.com',
      Username = 'elsewhere.' + UserInfo.getOrganizationId() + '.' + System.now().getTime() + '@parser.example.com',
      TimeZoneSidKey = 'Pacific/Kiritimati',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    System.runAs(elsewhere) {
      for (String text : writtenByText.keySet()) {
        System.assertEquals(writtenByText.get(text), core.model(Account.SObjectType).parseCondition(text).toSoql());
      }
    }
  }

  @isTest
  static void soqlEscapeSequencesInTextAreRead() {
    ConditionParser parser = new ConditionParser();

    System.assertEquals('O\'Brien \\ "x"', parser.tokenize('Name = \'O\\\'Brien \\\\ \\"x\\"\'')[2].value);
    System.assertEquals('a\nb\tc\rd', parser.tokenize('Name = \'a\\nb\\Tc\\rd\'')[2].value);
    System.assertEquals('a\bb\fc', parser.tokenize('Name = \'a\\bb\\Fc\'')[2].value);
    System.assertEquals('caf\u00e9', parser.tokenize('Name = \'caf\\u00e9\'')[2].value);
    System.assertEquals('50\\% off\\_', parser.tokenize('Name LIKE \'50\\% off\\_\'')[2].value, 'kept: LIKE reads them');
    System.assertEquals('a\\qb', parser.tokenize('Name = \'a\\qb\'')[2].value, 'not an escape sequence, so kept as it is');
    System.assertEquals('\\uZZ', parser.tokenize('Name = \'\\uZZ\'')[2].value, 'not four hex digits');

    // What toSoql() writes, parseCondition() reads back
    IModel accountModel = core.model(Account.SObjectType);
    ICondition quoted = core.eq(Account.Name, 'O\'Brien \\ x');
    ICondition readBack = accountModel.parseCondition(quoted.toSoql());
    System.assertEquals(quoted.toSoql(), readBack.toSoql());
    System.assert(readBack.evaluate(new Account(Name = 'O\'Brien \\ x')));

    ICondition pattern = accountModel.parseCondition(core.lk(Account.Name, '50\\% off%').toSoql());
    System.assert(pattern.evaluate(new Account(Name = '50% off today')));
    System.assert(!pattern.evaluate(new Account(Name = '500 off today')));
  }

  @isTest
  static void aListOfWholeAndDecimalNumbersIsRead() {
    IModel accountModel = core.model(Account.SObjectType);
    ICondition mixed = accountModel.parseCondition('AnnualRevenue IN (0, 10.5, 12345678901)');

    System.assert(mixed.evaluate(new Account(AnnualRevenue = 0)));
    System.assert(mixed.evaluate(new Account(AnnualRevenue = 10.5)));
    System.assert(mixed.evaluate(new Account(AnnualRevenue = 12345678901L)));
    System.assert(!mixed.evaluate(new Account(AnnualRevenue = 10)));

    ICondition large = accountModel.parseCondition('AnnualRevenue > 12345678901');
    System.assert(large.evaluate(new Account(AnnualRevenue = 12345678902L)), 'too long for an Integer, so a Long');
    System.assert(!large.evaluate(new Account(AnnualRevenue = 5)));
  }

  @isTest
  static void aPathThroughAPolymorphicLookupIsRead() {
    IModel tasks = core.model(Task.SObjectType);
    String text = '(What.Type = \'Account\' AND Owner.Name != \'Nobody\' AND Who.Email LIKE \'%@example.com\')';

    System.assertEquals(text, tasks.parseCondition(text).toSoql());
    System.assert(
      tasks.parseCondition('What.Type = \'Account\'').evaluate(new Task(WhatId = IdUtil.generateId(Account.SObjectType))),
      'the type is read from the Id when the record carries no more'
    );
    try {
      tasks.parseCondition('What.Industry = \'Energy\'');
      System.assert(false, 'Industry is a field of Account, not of everything What can point at');
    } catch (Modeling.PathException e) {
      System.assert(e.getMessage().endsWith('What can point at several objects, and Industry is not a field of them all'), e.getMessage());
    }
  }

  @isTest
  static void aGroupEndsAtItsClosingBracket() {
    // Sixteen accounts: every combination of four fields that each hold one of two values
    List<Account> rows = new List<Account>();
    for (Integer bits = 0; bits < 16; bits++) {
      rows.add(
        new Account(
          Industry = Math.mod(bits, 2) == 1 ? 'Retail' : 'Energy',
          Type = Math.mod(bits / 2, 2) == 1 ? 'Prospect' : 'Other',
          Name = Math.mod(bits / 4, 2) == 1 ? 'Acme' : 'Beta',
          Rating = Math.mod(bits / 8, 2) == 1 ? 'Hot' : 'Cold'
        )
      );
    }
    insert rows;
    String retail = 'Industry = \'Retail\'';
    String prospect = 'Type = \'Prospect\'';
    String acme = 'Name = \'Acme\'';
    String hot = 'Rating = \'Hot\'';
    // For each text: the condition as toSoql() brackets it, and how many of the sixteen it matches
    Map<String, List<Object>> expectedByText = new Map<String, List<Object>>{
      'NOT (' + retail + ' AND ' + prospect + ') AND ' + acme => new List<Object>{
        '((NOT (' + retail + ' AND ' + prospect + ')) AND ' + acme + ')',
        6
      },
      'NOT (' + retail + ' OR ' + prospect + ') OR ' + acme => new List<Object>{
        '((NOT (' + retail + ' OR ' + prospect + ')) OR ' + acme + ')',
        10
      },
      '(' + retail + ' AND ' + prospect + ') AND ' + acme => new List<Object>{
        '((' + retail + ' AND ' + prospect + ') AND ' + acme + ')',
        2
      },
      '(' + retail + ' OR ' + prospect + ') OR ' + acme => new List<Object>{
        '((' + retail + ' OR ' + prospect + ') OR ' + acme + ')',
        14
      },
      acme + ' AND NOT (' + retail + ' AND ' + prospect + ') AND ' + hot => new List<Object>{
        '(' + acme + ' AND (NOT (' + retail + ' AND ' + prospect + ')) AND ' + hot + ')',
        3
      },
      'NOT (' + retail + ' AND ' + prospect + ') AND ' + acme + ' AND ' + hot => new List<Object>{
        '((NOT (' + retail + ' AND ' + prospect + ')) AND ' + acme + ' AND ' + hot + ')',
        3
      },
      acme + ' OR NOT (' + retail + ' OR ' + prospect + ') OR ' + hot => new List<Object>{
        '(' + acme + ' OR (NOT (' + retail + ' OR ' + prospect + ')) OR ' + hot + ')',
        13
      },
      'NOT (' + retail + ' OR ' + prospect + ') OR ' + acme + ' AND ' + hot => new List<Object>{
        '((NOT (' + retail + ' OR ' + prospect + ')) OR (' + acme + ' AND ' + hot + '))',
        7
      },
      'NOT (NOT (' + retail + ' AND ' + prospect + ') AND ' + acme + ')' => new List<Object>{
        '(NOT ((NOT (' + retail + ' AND ' + prospect + ')) AND ' + acme + '))',
        10
      },
      'NOT (' + retail + ' AND NOT (' + prospect + ' OR ' + acme + '))' => new List<Object>{
        '(NOT (' + retail + ' AND (NOT (' + prospect + ' OR ' + acme + '))))',
        14
      },
      'NOT ' + retail + ' AND ' + prospect => new List<Object>{ '((NOT ' + retail + ') AND ' + prospect + ')', 4 },
      'NOT (NOT (' + retail + ' AND ' + prospect + '))' => new List<Object>{ '(' + retail + ' AND ' + prospect + ')', 4 },
      'NOT NOT (' + retail + ' AND ' + prospect + ')' => new List<Object>{ '(' + retail + ' AND ' + prospect + ')', 4 },
      'NOT NOT NOT ' + retail => new List<Object>{ '(NOT ' + retail + ')', 8 }
    };
    // The platform takes these as they stand; it wants more brackets around the others
    Set<String> runsAsWritten = new Set<String>{
      '(' + retail + ' AND ' + prospect + ') AND ' + acme,
      '(' + retail + ' OR ' + prospect + ') OR ' + acme,
      'NOT (NOT (' + retail + ' AND ' + prospect + '))'
    };
    IModel accountModel = core.model(Account.SObjectType);

    for (String text : expectedByText.keySet()) {
      ICondition parsed = accountModel.parseCondition(text);
      Set<Id> inMemory = new Set<Id>();
      for (Account row : rows) {
        if (parsed.evaluate(row)) {
          inMemory.add(row.Id);
        }
      }

      System.assertEquals((String) expectedByText.get(text)[0], parsed.toSoql(), text);
      System.assertEquals((Integer) expectedByText.get(text)[1], inMemory.size(), text);
      System.assertEquals(idsOf(Database.query('SELECT Id FROM Account WHERE ' + parsed.toSoql())), inMemory, text);
      if (runsAsWritten.contains(text)) {
        System.assertEquals(idsOf(Database.query('SELECT Id FROM Account WHERE ' + text)), inMemory, text);
      }
    }
  }

  private static Set<Id> idsOf(List<SObject> rows) {
    return new Map<Id, SObject>(rows).keySet();
  }

  @isTest
  static void quotedTextIsTextWhateverItLooksLike() {
    IModel accountModel = core.model(Account.SObjectType);
    Map<String, Account> matchByText = new Map<String, Account>{
      'BillingPostalCode = \'94105\'' => new Account(BillingPostalCode = '94105'),
      'Name = \'123\'' => new Account(Name = '123'),
      'Name = \'-12.50\'' => new Account(Name = '-12.50'),
      'Name = \'2026-01-31\'' => new Account(Name = '2026-01-31'),
      'Name = \'2026-01-31T09:30:00Z\'' => new Account(Name = '2026-01-31T09:30:00Z'),
      'Name = \'09:30:00.000Z\'' => new Account(Name = '09:30:00.000Z'),
      'Name = \'TODAY\'' => new Account(Name = 'today'),
      'Name = \'true\'' => new Account(Name = 'TRUE'),
      'Name = \'null\'' => new Account(Name = 'null'),
      'Name IN (\'123\', \'2026-01-31\')' => new Account(Name = '2026-01-31'),
      'Name LIKE \'2026-01-%\'' => new Account(Name = '2026-01-31')
    };

    for (String text : matchByText.keySet()) {
      ICondition parsed = accountModel.parseCondition(text);
      System.assertEquals(text, parsed.toSoql(), 'read and written back the same');
      System.assert(parsed.evaluate(matchByText.get(text)), text);
    }
    System.assertEquals('Name = \'123\'', accountModel.parseCondition(core.eq(Account.Name, '123').toSoql()).toSoql());

    // A quoted value is not a number, a date or a checkbox, here or on the platform
    insert new Account(Name = 'Five', NumberOfEmployees = 5);
    for (String text : new List<String>{
      'NumberOfEmployees = \'5\'',
      'AnnualRevenue > \'5\'',
      'CreatedDate > \'2026-01-31T09:30:00Z\'',
      'LastActivityDate = \'2026-01-31\'',
      'IsDeleted = \'false\''
    }) {
      try {
        accountModel.parseCondition(text);
        System.assert(false, 'Quoted text was read as a value of another type: ' + text);
      } catch (Typing.ValidationException e) {
        System.assert(e.getMessage().endsWith('so it cannot be compared with string'), e.getMessage());
      }
      try {
        Database.query('SELECT Id FROM Account WHERE ' + text);
        System.assert(false, 'The platform took ' + text);
      } catch (QueryException e) {
        System.assert(e.getMessage().endsWith('should not be enclosed in quotes'), e.getMessage());
      }
    }
    System.assertEquals(1, Database.query('SELECT Id FROM Account WHERE NumberOfEmployees = 5').size());
    System.assert(accountModel.parseCondition('NumberOfEmployees = 5').evaluate(new Account(NumberOfEmployees = 5)));
  }

  @isTest
  static void whatToSoqlWritesIsReadBack() {
    Id accountId = IdUtil.generateId(Account.SObjectType);
    List<ICondition> written = new List<ICondition>{
      core.eq(Account.Name, 'O\'Brien \\ 50%'),
      core.eq(Account.Name, '123'),
      core.ne(Account.Name, null),
      core.lk(Account.Name, 'Ac\\%me_%'),
      core.eq(Account.Id, accountId),
      core.iin(Account.Id, new Set<Id>{ accountId }),
      core.nin(Account.Industry, new List<String>{ 'Energy', 'Retail' }),
      core.iin(Account.Industry, new List<String>()),
      core.eq(Account.NumberOfEmployees, 5),
      core.lt(Account.NumberOfEmployees, -5),
      core.ge(Account.AnnualRevenue, 12345678901L),
      core.le(Account.AnnualRevenue, 1234.5),
      core.iin(Account.AnnualRevenue, new List<Decimal>{ 0, 10.5 }),
      core.eq(Account.IsDeleted, true),
      core.eq(Account.LastActivityDate, Date.newInstance(2026, 1, 31)),
      core.gt(Account.CreatedDate, Date.newInstance(2026, 1, 31)),
      core.le(Account.CreatedDate, Datetime.newInstanceGmt(2026, 1, 31, 9, 30, 15)),
      core.ge(Account.CreatedDate, DateLiteral.lastNDays(30)),
      core.iin(Account.CreatedDate, new List<IDateLiteral>{ DateLiteral.today(), DateLiteral.nFiscalQuartersAgo(2) }),
      core.neg(core.eq(Account.Name, 'Acme')),
      core.all(
        new List<ICondition>{
          core.eq(Account.Name, 'Acme'),
          core.neg(core.any(new List<ICondition>{ core.eq(Account.Industry, 'Energy'), core.gt(Account.AnnualRevenue, 5) }))
        }
      ),
      core.eq(new List<SObjectField>{ Account.OwnerId, User.Email }, 'someone@example.com'),
      core.ge(BusinessHours.MondayStartTime, Time.newInstance(9, 30, 0, 0)),
      core.iin(BusinessHours.MondayStartTime, new List<Time>{ Time.newInstance(0, 0, 0, 0), Time.newInstance(23, 59, 59, 999) }),
      core.model(Task.SObjectType).parseCondition('What.Type = \'Account\' AND Owner.Name != null')
    };

    for (ICondition each : written) {
      if (each.source() == null) {
        each.realize(Account.SObjectType);
      }
      String soql = each.toSoql();
      ICondition readBack = each.source().parseCondition(soql);
      System.assertEquals(soql, readBack.toSoql(), 'read back and written again');
    }
  }
}
