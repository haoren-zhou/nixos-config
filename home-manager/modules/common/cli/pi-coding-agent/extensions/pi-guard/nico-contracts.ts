import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pi Subagents does not expose its child-session factory as public API. Keep the
// private seam structural and narrow so upstream changes fail at this boundary.
export interface ChildRuntimeContract {
  parentSessionId?: string;
  depth: number;
  maxDepth?: number;
  agent: string;
  fanoutChild: boolean;
  capabilityCeiling?: { denyExtensions?: boolean };
}

export interface ChildExtensionError {
  error: unknown;
  [key: string]: unknown;
}

export interface ChildSessionLaunch {
  runtime: ChildRuntimeContract;
  tools?: string[];
  extensionPaths: string[];
  ambientExtensions: boolean;
  excludeTools?: string[];
  hooks: Array<{
    name: string;
    factory(pi: ExtensionAPI): void | Promise<void>;
  }>;
  processEnv?: Record<string, string | undefined>;
  onExtensionError?(error: ChildExtensionError): void;
  [key: string]: unknown;
}

type ChildInputMethod = (
  text: string,
  ...additional: unknown[]
) => Promise<unknown>;

export interface ChildSession {
  readonly sessionId: string;
  prompt: ChildInputMethod;
  steer: ChildInputMethod;
  followUp: ChildInputMethod;
  abort(): Promise<unknown>;
  dispose(): Promise<unknown>;
  [key: string]: unknown;
}

export interface ChildSessionFactory {
  create(launch: ChildSessionLaunch): Promise<ChildSession>;
  dispose(): Promise<void>;
}

export interface ChildSessionFactoryModule {
  childSessionFactory(): ChildSessionFactory;
  childSessionFactoryModule(): string | undefined;
  createDefaultChildSessionFactory(options: {
    loadPiCodingAgent(): Promise<
      typeof import("@earendil-works/pi-coding-agent")
    >;
  }): ChildSessionFactory;
  setChildSessionFactory(factory: ChildSessionFactory): void;
  setChildSessionFactoryModule(path: string): void;
}

export interface RuntimeAgentRegistration {
  dispose(): void;
}

export interface RuntimeAgentRegistrationRequest {
  version: 1;
  name: string;
  definition: {
    description: string;
    systemPrompt: string;
    systemPromptMode: "append" | "replace";
    inheritProjectContext: boolean;
    defaultContext: "fresh" | "fork" | "profile";
    defaultAsync: boolean;
    extensions: string[];
    excludeTools: string[];
  };
  result?:
    | { ok: true; registration: RuntimeAgentRegistration }
    | { ok: false; error: Error };
}

export interface CapabilityCeilingHandle {
  dispose(): void;
}

export type RegisterCapabilityCeiling = (options: {
  sessionId: string;
  source: string;
  ceiling: { allowedAgents: readonly string[] };
}) => CapabilityCeilingHandle;

export interface CapabilityCeilingModule {
  registerSubagentCapabilityCeiling: RegisterCapabilityCeiling;
}
