# History tracker

A canister for canister history tracking.

## Local setup

It is assumed that you have:
- Dfinity SDK installed
- NodeJS installed
- yarn installed

Once you have cloned the repository, follow this process in your terminal:

1. In your project directory, run this command to install yarn dependencies:
```
yarn install
```
2. Start local Internet Computer replica:
```
dfx start --clean --background
```
3. Generate canister type declarations:
```
dfx generate
```
4. Deploy canisters locally:
```
dfx deploy
```

## Copyright

MR Research AG, 2024

## License

Apache-2.0