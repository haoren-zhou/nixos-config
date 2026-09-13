import { fileURLToPath } from "node:url";
import * as sdk from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "./dependencies.ts";
import type { NativeBinding } from "./native-child.ts";
import { bridgeSdk, nativeChildHook } from "./child-resources.ts";
import { getPermissionsService } from "./shared.ts";
import { assertLeaseLive, readLease, type LeaseRef } from "./leases.ts";
import type {
  ChildExtensionError,
  ChildSessionFactory,
  ChildSessionFactoryModule,
} from "./nico-contracts.ts";

const childSessions = (await import(
  dependencyPath("pi-subagents", "src/runs/shared/child-session.ts")
)) as unknown as ChildSessionFactoryModule;
const {
  childSessionFactory,
  childSessionFactoryModule,
  createDefaultChildSessionFactory,
  setChildSessionFactory,
  setChildSessionFactoryModule,
} = childSessions;

const INSTALLATIONS_KEY = Symbol.for("hr.pi-guard.normal-factory.v4");
const defaultFactory = childSessionFactory();
interface Installation {
  factory: ChildSessionFactory;
  modulePath: string;
}
const denied = (reason: string) => new Error(`Pi Guard: ${reason}`);

export function createGuardedFactory(
  base: ChildSessionFactory,
  runner = false,
): ChildSessionFactory {
  let runnerOwner: LeaseRef | undefined;
  return {
    async create(launch) {
      const runtime = launch.runtime;
      if (
        !runtime.parentSessionId ||
        !Number.isInteger(runtime.depth) ||
        runtime.depth < 1 ||
        (runtime.maxDepth !== undefined && runtime.depth > runtime.maxDepth)
      )
        throw denied("invalid native parent/depth contract");
      const parent = readLease(runtime.parentSessionId);
      if (!parent)
        throw denied("no live binding for the declared parent session");
      assertLeaseLive(parent);
      const remote = parent.pid !== process.pid;
      if (remote) {
        if (!runner || process.env.PI_SUBAGENT_CHILD !== "1")
          throw denied("remote parent requires the detached runner factory");
        if (
          runnerOwner &&
          (runnerOwner.sessionId !== parent.sessionId ||
            runnerOwner.generation !== parent.generation)
        )
          throw denied("detached runner cannot change permission owner");
        runnerOwner ??= {
          sessionId: parent.sessionId,
          generation: parent.generation,
        };
      }
      const binding: NativeBinding = {
        parent,
        remote,
        allowNested: runtime.fanoutChild,
        active: false,
      };
      const errors: ChildExtensionError[] = [];
      const child = await base
        .create({
          ...launch,
          // Tool selection, discovery, exclusions and fanout stay Nico-owned.
          hooks: [nativeChildHook(binding), ...launch.hooks],
          ...(remote
            ? {
                processEnv: {
                  ...launch.processEnv,
                  PI_AGENT_ROUTER_PARENT_SESSION_ID: undefined,
                  PI_SUBAGENT_PARENT_SESSION: parent.sessionId,
                },
              }
            : {}),
          onExtensionError(error) {
            errors.push(error);
            launch.onExtensionError?.(error);
          },
        })
        .catch((error) => {
          binding.close?.();
          throw error;
        });
      const bound = () => {
        if (
          !binding.permissionReady ||
          !binding.active ||
          !binding.lease ||
          binding.lease.sessionId !== child.sessionId ||
          !getPermissionsService(child.sessionId)
        )
          throw denied(
            `child permission activation failed${errors.length ? `: ${String(errors[0]?.error ?? errors[0]).slice(0, 800)}` : ` (active=${binding.active}, lease=${!!binding.lease})`}`,
          );
        assertLeaseLive(binding.lease);
      };
      try {
        bound();
      } catch (error) {
        await child.dispose();
        throw error;
      }
      // Preserve original handle identity and every upstream capability/session
      // lease. History is resumed, authority never is: each create binds anew.
      for (const method of ["prompt", "steer", "followUp"] as const) {
        const original = child[method];
        child[method] = async (...args) => {
          bound();
          const result = await Reflect.apply(original, child, args);
          bound();
          return result;
        };
      }
      const abort = child.abort.bind(child);
      child.abort = () => {
        binding.close?.();
        return abort();
      };
      return child;
    },
    dispose: () => base.dispose(),
  };
}

export function installChildSessionGuard(runner = false): ChildSessionFactory {
  const global = globalThis as Record<symbol, unknown>;
  const obsoleteKeys = [
    ...["v1", "v2", "v3"].map(
      (version) => `hr.pi-guard.normal-factory.${version}`,
    ),
    ...["v1", "v2", "v3"].map(
      (version) => `hr.pi-guard-prototype.normal-factory.${version}`,
    ),
  ];
  if (obsoleteKeys.some((key) => global[Symbol.for(key)]))
    throw denied("restart Pi to upgrade the previous factory integration");
  // Each real Pi reload creates a NEW loader graph. Bind that graph's Nico
  // getter, while leaving old graphs guarded until their owners dispose them.
  const installations = (global[INSTALLATIONS_KEY] ??= new WeakMap<
    Function,
    Installation
  >()) as WeakMap<Function, Installation>;
  const existing = installations.get(childSessionFactory);
  if (existing) {
    if (
      childSessionFactory() !== existing.factory ||
      childSessionFactoryModule() !== existing.modulePath
    )
      throw denied(
        "native factory ownership changed; refusing to overwrite another integration",
      );
    return existing.factory;
  }
  if (
    childSessionFactoryModule() !== undefined ||
    childSessionFactory() !== defaultFactory
  )
    throw denied("a native factory integration already exists");
  // The SDK facade uses the stock resource loader, adapting only permission
  // handlers after discovery. The explicit SDK also supports Nix's Bun runner.
  const base = createDefaultChildSessionFactory({
    loadPiCodingAgent: async () => bridgeSdk(sdk),
  });
  const factory = createGuardedFactory(base, runner);
  const modulePath = fileURLToPath(new URL("./runner.ts", import.meta.url));
  setChildSessionFactory(factory);
  setChildSessionFactoryModule(modulePath);
  installations.set(childSessionFactory, { factory, modulePath });
  return factory;
}
