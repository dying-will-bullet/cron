# Cron Fuzz Test

### Environment Setup

Install the dependencies.

```
$ bash setup.sh
```

Generate test data.

```
$ python gen.py
```

The test data will be generated in the `testdata` directory of the curren path.

### Run Tests

```
zig build run-fuzz
```
