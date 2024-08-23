export default {
    roots: ['<rootDir>'],
    testEnvironment: 'node',
    moduleFileExtensions: ['js', 'mjs', 'json', 'jsx', 'ts', 'tsx', 'node'],
    testMatch: ['**/?(*.)+(spec|test).[jt]s?(x)', '**/?(*.)+(spec|test).mjs'],
    clearMocks: true,
    testTimeout: 500000,
    testPathIgnorePatterns: ['/node_modules/', '/dist/'],
    transform: {
      '^.+\\.m?[tj]sx?$': 'babel-jest'
    }
  };