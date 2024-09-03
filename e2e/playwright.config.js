import { defineConfig, devices } from '@playwright/test';

/**
 * @see https://playwright.dev/docs/test-configuration
 */
module.exports = defineConfig({

	testDir: "./__tests__",

	/* Maximum time one test can run for. */
	timeout: 500 * 1000,

	/* Fail the build on CI if you accidentally left test.only in the source code. */
	forbidOnly: !!process.env.CI,

	/* Retry on CI only */
	retries: 0,

	/* Opt out of parallel tests on CI. */
	workers: 1,

	/* Reporter to use. See https://playwright.dev/docs/test-reporters */
	reporter: "list",
	
	/* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
	use: {
		/* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
		trace: "on",
	},

	/* Configure projects for major browsers */
	projects: [
		{
			name: "chromium",
			use: { ...devices["Desktop Chrome"] },
		},
	],
});
