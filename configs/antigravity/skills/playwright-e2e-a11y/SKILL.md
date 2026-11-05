---
name: playwright-e2e-a11y
description: Automated browser testing and accessibility auditing with Playwright in TypeScript, enforcing Page Object Models (POM), Microsoft Edge channel configuration, network failure mocking, and automated WCAG 2.1 AA audits via axe-core.
---

# Playwright E2E & Accessibility (A11y) Testing Guide

Production standards for automated browser testing and automated accessibility auditing using **Playwright** (TypeScript), Microsoft Edge browser channel, the **Page Object Model (POM)** pattern, and **@axe-core/playwright**.

---

## When to Use This Skill

Trigger whenever designing, authoring, or debugging automated web test suites:
- Creating end-to-end (E2E) integration and smoke tests for web applications.
- Enforcing WCAG 2.1 Level AA accessibility compliance via automated scanning.
- Structuring UI test code with modular, maintainable Page Object Models.
- Configuring Playwright to leverage Microsoft Edge (`channel: 'msedge'`) avoiding ad-hoc Chromium downloads.
- Simulating edge cases: network timeouts, 500 internal server errors, offline mode, and API request throttling.

---

## 1. Playwright Configuration with Microsoft Edge Channel

Configure `playwright.config.ts` to use the pre-installed Microsoft Edge browser channel to guarantee deterministic rendering and avoid unwanted browser downloads.

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'Microsoft Edge',
      use: {
        ...devices['Desktop Edge'],
        channel: 'msedge',
      },
    },
  ],
});
```

---

## 2. Page Object Model (POM) Architecture

Organize UI interactions into dedicated Page Objects using user-facing role locators (`getByRole`, `getByLabel`, `getByText`) rather than fragile CSS selectors or XPath.

### Page Object Definition
```typescript
// e2e/pages/LoginPage.ts
import { type Locator, type Page, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByRole('textbox', { name: /email/i });
    this.passwordInput = page.getByLabel(/password/i);
    this.submitButton = page.getByRole('button', { name: /sign in/i });
    this.errorMessage = page.getByRole('alert');
  }

  async goto(): Promise<void> {
    await this.page.goto('/login');
    await expect(this.submitButton).toBeVisible();
  }

  async login(email: string, pass: string): Promise<void> {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(pass);
    await this.submitButton.click();
  }

  async expectErrorMessage(message: string | RegExp): Promise<void> {
    await expect(this.errorMessage).toBeVisible();
    await expect(this.errorMessage).toContainText(message);
  }
}
```

### Clean Test Execution
```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';
import { LoginPage } from './pages/LoginPage';

test.describe('Authentication Flow', () => {
  test('displays validation error on invalid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('invalid@example.com', 'wrongpassword');
    await loginPage.expectErrorMessage(/invalid email or password/i);
  });
});
```

---

## 3. Automated Accessibility Auditing with `@axe-core/playwright`

Automate WCAG 2.1 Level AA accessibility checks on every critical view and dynamic state.

### Full-Page & Scoped Accessibility Spec
```typescript
// e2e/a11y.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility Standards (WCAG 2.1 AA)', () => {
  test('homepage passes automated WCAG AA audit', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('modal dialog maintains focus trap and passes audit', async ({ page }) => {
    await page.goto('/settings');
    await page.getByRole('button', { name: /edit profile/i }).click();

    // Verify modal container specifically
    const modalScanResults = await new AxeBuilder({ page })
      .include('[role="dialog"]')
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(modalScanResults.violations).toEqual([]);
  });
});
```

---

## 4. Network Interception & Failure Simulation

Never rely on live third-party services in tests. Mock API endpoints to simulate edge conditions and resilience.

### Simulating API Failures & Throttling
```typescript
// e2e/network-edge-cases.spec.ts
import { test, expect } from '@playwright/test';

test.describe('API Boundary Resilience', () => {
  test('gracefully handles 500 Internal Server Error', async ({ page }) => {
    // Intercept API call and return simulated server fault
    await page.route('**/api/v1/orders', async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'Database unavailable' }),
      });
    });

    await page.goto('/checkout');
    await page.getByRole('button', { name: /confirm order/i }).click();

    await expect(page.getByRole('alert')).toContainText(/unable to process order/i);
  });

  test('survives offline network transitions', async ({ page, context }) => {
    await page.goto('/dashboard');

    // Simulate network disconnection
    await context.setOffline(true);

    await page.getByRole('button', { name: /refresh data/i }).click();
    await expect(page.getByText(/you are currently offline/i)).toBeVisible();

    // Restore connectivity
    await context.setOffline(false);
    await page.getByRole('button', { name: /retry/i }).click();
    await expect(page.getByText(/you are currently offline/i)).toBeHidden();
  });
});
```

---

## 5. Command-Line Execution Reference

```bash
# Run all tests using configured Microsoft Edge channel
npx playwright test

# Run a specific spec file
npx playwright test e2e/a11y.spec.ts

# Run tests in headed mode for visual debugging
npx playwright test --headed

# Open interactive Playwright UI mode
npx playwright test --ui

# Inspect failed test trace
npx playwright show-trace test-results/trace.zip
```
