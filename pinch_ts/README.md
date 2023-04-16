# PinchTs and Nx
The Typescipt here uses the [Nx](https://nx.dev/getting-started/intro) monorepo which should help us manage our Typescript and not have redundant code.

## Getting started
First, add all packages by running: 
```
yarn
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
To run the sequencer simply run
```
npx nx serve sequencer
```

##
