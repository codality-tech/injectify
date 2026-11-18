/**
 * A scheme that also runs SOSL. It is optional: a search goes through its scheme when the scheme
 * implements this interface, and straight to the platform when it does not.
 */
global interface ISearchScheme {
  List<List<SObject>> search(String sosl, System.AccessLevel accessLevel);
}
