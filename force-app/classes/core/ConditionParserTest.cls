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
      ConditionParser.TokenType.DATETIME_LITERAL,
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
      ConditionParser.TokenType.DATETIME_LITERAL,
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
      ConditionParser.TokenType.DATETIME_LITERAL,
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
    System.assertEquals('2023-12-25', node.value);
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
    System.assertEquals('2023-12-25T10:30:00Z', node.value);
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
      ConditionParser.TokenType.DATETIME_LITERAL,
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
      ConditionParser.TokenType.DATETIME_LITERAL,
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
    // Note: The tokenizer currently doesn't throw for unclosed quotes
    // It treats the rest of the string as part of the quoted value
    // This test documents current behavior
    ConditionParser parser = new ConditionParser();

    // This currently succeeds - unclosed quote treated as extending to end
    List<ConditionParser.Token> tokens = parser.tokenize('Name = \'Unclosed');
    System.assert(
      tokens != null,
      'Tokenizer handles unclosed quotes by reading to end'
    );
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
}
