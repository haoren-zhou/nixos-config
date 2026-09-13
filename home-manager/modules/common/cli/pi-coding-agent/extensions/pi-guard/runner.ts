import { installChildSessionGuard } from "./child-session-guard.ts";

// Loaded by Nico's actual detached-runner seam before child session creation.
// Also installs the same protected factory for foreground grandchildren and
// carries this module into any detached descendants. Missing module = failure.
export default function guardedRunner() {
  if (process.env.PI_SUBAGENT_CHILD !== "1")
    throw new Error("Guard runner requires a detached subagent process");
  return installChildSessionGuard(true);
}
