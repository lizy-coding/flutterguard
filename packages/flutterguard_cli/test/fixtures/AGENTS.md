# Fixture Layer

## Responsibility
This directory contains intentionally imperfect Dart/YAML files used by CLI rule tests.

## Rules
- Fixtures may intentionally violate style or architecture rules.
- Keep fixture names tied to the rule or scenario they exercise.
- Do not import app dependencies; fixtures should remain plain Dart snippets where possible.
- When adding architecture fixtures, update or add a matching YAML config.
- Avoid broad fixture changes because many tests can depend on the same file.
