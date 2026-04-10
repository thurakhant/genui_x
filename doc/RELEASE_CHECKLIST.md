# Release Checklist

Use this workflow for every release to reduce mistakes and keep quality high.

## 1) Plan the scope

- Define the version target (e.g., 0.0.4)
- List features, fixes, and tests
- Decide what docs need updates

## 2) Create a release branch

```bash
git checkout -b release/x.y.z
```

## 3) Implement changes

- Keep changes focused on the planned scope
- Prefer small, readable commits

## 4) Run checks

```bash
flutter analyze
flutter test
```

## 5) Update docs and changelog

- `CHANGELOG.md` top entry matches the version
- README examples reflect new behavior
- Update or add example apps if needed

## 6) Bump version

```yaml
# pubspec.yaml
version: x.y.z
```

## 7) Commit and tag

```bash
git add .
git commit -m "chore: release x.y.z"
git tag -a vx.y.z -m "vx.y.z"
```

## 8) Dry-run publish

```bash
flutter pub publish --dry-run
```

## 9) Publish

```bash
flutter pub publish
```
