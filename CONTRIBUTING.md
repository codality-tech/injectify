# Contributing

Thanks for helping. This page covers setting up, the rules a change must follow, and how to send it.

## Setting up

You need the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) and a Dev Hub.

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias framework-dev --duration-days 30
sf project deploy start -d force-app -o framework-dev
sf apex test run -l RunLocalTests -c -o framework-dev
```

All tests should pass before you start.

## Making a change

- **Every class has a test class**, and a change comes with tests that would fail without it. Prefer exact assertions (`Assert.areEqual`) over "did not throw".
- **Bind, don't concatenate.** Values in queries go through conditions so they are bound when the query runs; never build SOQL or SOSL from user input.
- **Keep the global surface small.** `global` is for interfaces and entry points subscribers need. If you add, change or remove anything `global` or `public`, run the API report and review it:

  ```bash
  py scripts/py/package_api.py   # writes docs/documentation/package_api.apex
  ```

- **Update the docs in the same change**: the guide that covers the area (`docs/documentation/`), the README if the tour or feature list changes, and `CHANGELOG.md` under *Unreleased*.
- **Measure before optimizing.** For CPU work, compare `Limits.getCpuTime()` before and after on a scratch org, and put the numbers in the pull request.
- Run Salesforce Code Analyzer and fix any new high-severity finding (it runs locally):

  ```bash
  sf code-analyzer run -w force-app -r Recommended -r AppExchange
  ```

- Run the whole suite before you open a pull request:

  ```bash
  sf apex test run -l RunLocalTests -c -o framework-dev
  ```

## Sending it

- One topic per pull request, with a description of the behavior change and how it was tested.
- Write commit messages that say what changed and why, in the imperative ("Bind aggregate query values").
- Report security issues privately rather than in a public issue.
