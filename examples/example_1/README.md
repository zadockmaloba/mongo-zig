# Example 1

## Options for running

* With MongoDB already running locally on 27017:

    ```shell
    zig build run
    ```

* Without MongoDB running locally on 27017:

    ```shell
    docker compose up -d
    zig build run
    docker compose stop
    ```

* With MongoDB running in a different location:

    ```shell
    zig build run -- localhost:1234
    ```

## Options for testing

* With MongoDB already running locally on 27017:

    ```shell
    zig build test
    ```

* Without MongoDB running locally on 27017:

    ```shell
    docker compose up -d
    zig build test
    docker compose stop
    ```
