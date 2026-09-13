export interface CleanupStep {
  name: string;
  run(): void;
}

/** Run every revocation step even when one cleanup mechanism fails. */
export function runCleanup(scope: string, steps: CleanupStep[]): void {
  const failures: string[] = [];
  for (const step of steps) {
    try {
      step.run();
    } catch (error) {
      failures.push(`${step.name}: ${String(error)}`);
    }
  }
  if (failures.length)
    console.error(`${scope} cleanup failed: ${failures.join("; ")}`);
}
