import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 0,
  workers: 1,
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    headless: true,
  },
  projects: [
    {
      name: 'canadiana',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'http://localhost:3000',
      },
    },
    {
      name: 'heritage',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'http://localhost:3010',
      },
    },
  ],
});
