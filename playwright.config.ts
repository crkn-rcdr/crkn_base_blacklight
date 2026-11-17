import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 0,
  workers: 1,
  use: {
    baseURL: process.env.BASE_URL || 'http://www2-beta-dev.canadiana.ca:8088',
    headless: true,
  },
  projects: [
    {
      name: 'canadiana',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: process.env.BASE_URL || 'http://www2-beta-dev.canadiana.ca:8088',
      },
    },
    {
      name: 'heritage',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: process.env.BASE_URL_HERITAGE || 'http://heritage-beta-dev.canadiana.ca:8088',
      },
    },
  ],
});
