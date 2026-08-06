# HistoryTracker

A canister for canister history tracking.

## Local setup

It is assumed that you have:
- `icp` CLI installed (see https://github.com/dfinity/icp-cli/releases)
- `ic-mops` installed (`npm i -g ic-mops`)
- NodeJS installed
- yarn installed

Once you have cloned the repository, follow this process in your terminal:

1. In your project directory, run this command to install yarn dependencies:
```
yarn install
```
2. Start the local network:
```
icp network start -d
```
3. Deploy canisters locally (this also builds them and generates the TypeScript bindings used by the frontend):
```
icp deploy
```
4. Start the frontend dev server:
```
yarn dev:frontend
```

## Copyright

MR Research AG, 2024

## License

Apache-2.0