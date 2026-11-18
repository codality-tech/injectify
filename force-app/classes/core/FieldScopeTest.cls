@isTest
public class FieldScopeTest {
  @isTest
  static void testTraitScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make(SoapType.ID);
    Set<SObjectField> keyFields = scope.apply(accountModel);
    System.assert(keyFields.contains(Account.Id), 'Should include Id');
  }

  @isTest
  static void testRegexScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make('.*Date$');
    Set<SObjectField> dateFields = scope.apply(accountModel);
    System.assert(dateFields.size() > 0, 'Should include date fields');
  }

  @isTest
  static void testUnionScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.any(
      new List<IFieldScope>{
        FieldScope.make(SoapType.ID),
        FieldScope.make('.*Street$')
      }
    );
    Set<SObjectField> result = scope.apply(accountModel);
    System.assert(
      result.contains(Account.BillingStreet),
      'Union should include BillingStreet'
    );
    System.assert(result.contains(Account.Id), 'Union should include Name');
  }

  @isTest
  static void testIntersectScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.all(
      new List<IFieldScope>{
        FieldScope.make(FieldScope.Trait.STANDARD),
        FieldScope.make(FieldScope.Trait.UNDERSIZE)
      }
    );
    Set<SObjectField> result = scope.apply(accountModel);
    System.assertNotEquals(
      0,
      result.size(),
      'Intersect should return fields that are both standard and undersize'
    );
  }

  @isTest
  static void testExclude() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make(FieldScope.Trait.ALL)
      .exclude(FieldScope.make(FieldScope.Trait.OVERSIZE));
    Set<SObjectField> result = scope.apply(accountModel);

    // Verify no oversize fields are included
    for (SObjectField field : result) {
      DescribeFieldResult describe = field.getDescribe();
      Boolean isOversize =
        describe.getType() == DisplayType.TEXTAREA &&
        describe.getLength() > 255;
      System.assert(
        !isOversize,
        'Should not include oversize fields: ' + field
      );
    }
  }

  @isTest
  static void testComplexComposition() {
    IModel accountModel = Application.s.model(Account.sObjectType);

    // (CUSTOM OR STANDARD) AND KEY = key fields that are either custom or standard
    IFieldScope scope = FieldScope.all(
      new List<IFieldScope>{
        FieldScope.any(
          new List<IFieldScope>{
            FieldScope.make(FieldScope.Trait.CUSTOM),
            FieldScope.make(FieldScope.Trait.STANDARD)
          }
        ),
        FieldScope.make(SoapType.DATE)
      }
    );

    Set<SObjectField> result = scope.apply(accountModel);
  }

  @isTest
  static void testMultipleExclusions() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make(FieldScope.Trait.ALL)
      .exclude(FieldScope.make(FieldScope.Trait.OVERSIZE))
      .exclude(FieldScope.make('.*__c$'));

    Set<SObjectField> result = scope.apply(accountModel);

    // Verify no oversize fields
    for (SObjectField field : result) {
      DescribeFieldResult describe = field.getDescribe();
      Boolean isOversize =
        describe.getType() == DisplayType.TEXTAREA &&
        describe.getLength() > 255;
      System.assert(!isOversize, 'Should not include oversize fields');

      String fieldName = String.valueOf(field);
      System.assert(
        !fieldName.endsWith('__c'),
        'Should not include custom fields: ' + fieldName
      );
    }
  }

  @isTest
  static void testRegexScopeWithInvalidRegex() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make('[invalid');
    Set<SObjectField> result = scope.apply(accountModel);
    System.assertEquals(
      0,
      result.size(),
      'Invalid regex should return empty set'
    );
  }

  @isTest
  static void testRegexScopeWithEmptyPattern() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make('');
    Set<SObjectField> result = scope.apply(accountModel);
    System.assertEquals(
      0,
      result.size(),
      'Empty regex should return empty set'
    );
  }

  @isTest
  static void testTraitScopeWithNullModel() {
    IFieldScope scope = FieldScope.make(SoapType.ID);
    Set<SObjectField> result = scope.apply(null);
    System.assertEquals(0, result.size(), 'null model should return empty set');
  }

  @isTest
  static void testUnionWithEmptyList() {
    IFieldScope scope = FieldScope.any(new List<IFieldScope>());
    IModel accountModel = Application.s.model(Account.sObjectType);
    Set<SObjectField> result = scope.apply(accountModel);
    System.assertEquals(
      0,
      result.size(),
      'Union of empty list should return empty set'
    );
  }

  @isTest
  static void testIntersectWithSingleScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.all(
      new List<IFieldScope>{ FieldScope.make(SoapType.ID) }
    );
    Set<SObjectField> result = scope.apply(accountModel);
    System.assert(
      result.contains(Account.Id),
      'Single scope intersect should work like regular scope'
    );
  }

  @isTest
  static void testPersonAccountExample() {
    IModel accountModel = Application.s.model(Account.sObjectType);

    // Example from scratch.apex: fields when person account is enabled
    IFieldScope scopePersonAccount = FieldScope.any(
      new List<IFieldScope>{
        FieldScope.make('Person\\w+'),
        FieldScope.make('\\w+__pc'),
        FieldScope.make('FirstName|LastName|Email')
      }
    );

    Set<SObjectField> result = scopePersonAccount.apply(accountModel);
    System.assertNotEquals(null, result, 'Should return a result set');
  }

  @isTest
  static void testLocalFKExample() {
    IModel accountModel = Application.s.model(Account.sObjectType);

    // Example from scratch.apex: (custom OR standard) AND (key) = non-namespaced key fields
    IFieldScope scopeLocalFK = FieldScope.all(
      new List<IFieldScope>{
        FieldScope.any(
          new List<IFieldScope>{
            FieldScope.make(FieldScope.Trait.CUSTOM),
            FieldScope.make(FieldScope.Trait.STANDARD)
          }
        ),
        FieldScope.make(SoapType.ID)
      }
    );

    Set<SObjectField> result = scopeLocalFK.apply(accountModel);
    System.assert(result.contains(Account.Id), 'Should include Id');
  }

  @isTest
  static void testSOAPTypeScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make(Schema.SOAPType.ID);
    Set<SObjectField> result = scope.apply(accountModel);

    // Account has ID type fields like Id, OwnerId, CreatedById, etc.
    System.assert(result.size() > 0, 'Should find ID type fields');
    System.assert(result.contains(Account.Id), 'Should include Id field');
  }

  @isTest
  static void testDisplayTypeScope() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make(DisplayType.STRING);
    Set<SObjectField> result = scope.apply(accountModel);

    // Account has string fields like Name, AccountNumber, etc.
    System.assert(result.size() > 0, 'Should find STRING type fields');
  }

  @isTest
  static void testDisplayTypeScopeWithDate() {
    IModel accountModel = Application.s.model(Account.sObjectType);
    IFieldScope scope = FieldScope.make(DisplayType.DATE);
    Set<SObjectField> result = scope.apply(accountModel);

    // Check that we can filter by DATE type
    System.assertNotEquals(null, result, 'Should return a result set');
  }
}
