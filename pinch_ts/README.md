# PinchTs and Nx
The Typescipt here uses the [Nx](https://nx.dev/getting-started/intro) monorepo which should help us manage our Typescript and not have redundant code.

## Getting started
First, add all packages by running: 
```
yarn
```

Then, for development, you need to run a local redis server. Any method works.
Our preferred method is to use docker:
```sh
docker run -d --name redis-stack-server -p 6379:6379 redis/redis-stack-server:latest
```

## Importing across libraries
To import a library package into an app, we can use a nice shorthand. For example, importing the `proof-utils` package, we can do
```ts
import { ProofUtils } from '@pinch-ts/proof-utils';
```

Generally, to import a library, we do
```ts
import <packageName> from '@pinch-ts/<package-name>'
```

# Using the different modules

## Sequencer
### Building TSOA, Swagger Documentation, and the Client Library
When modifying the controller file, one has to **rebuild** Tsoa by running
```sh
yarn nx run sequencer:build:tsoa-swagger
```

### Running the sequeuncer


To run the sequencer simply run
```
npx nx serve sequencer
```

### Running integration tests
To run integration tests, first make sure to have Redis running. Then, make sure to have a local EVM up and running.
```
cd smart-contracts && ./script/run_local_rpc.sh
```
Keep this terminal open.

In a separate terminal, run
```
cd smart-contracts && ./script/deploy_local.sh
```

Then, to run the `e2e` test,
run
```
yarn nx run sequencer-e2e:e2e
```

