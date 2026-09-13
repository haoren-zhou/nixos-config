import { realpathSync } from "node:fs";
import * as sdk from "@earendil-works/pi-coding-agent";
import { dependencyPath } from "./dependencies.ts";
import { attachNativeChild, type NativeBinding } from "./native-child.ts";

const permissionPath = dependencyPath(
  "@gotgenes/pi-permission-system",
  "src/index.ts",
);
const { default: permissionSystem } = await import(permissionPath);
const bindings = new WeakMap<sdk.ExtensionFactory, NativeBinding>();
const nativePath = "<inline:pi-guard:native-child>";
const promptPath = "<inline:pi-subagents:prompt-runtime>";

export function nativeChildHook(binding: NativeBinding) {
  const factory: sdk.ExtensionFactory = (pi) => attachNativeChild(pi, binding);
  bindings.set(factory, binding);
  return { name: "pi-guard:native-child", factory };
}

// Use the same SDK loader and upstream discovery policy. This adapter touches
// only permission handlers, not tools, providers, extension paths or settings.
export function bridgeSdk(base: typeof sdk = sdk): typeof sdk {
  return {
    ...base,
    DefaultResourceLoader: class extends base.DefaultResourceLoader {
      private binding?: NativeBinding;
      constructor(
        options: NonNullable<
          ConstructorParameters<typeof sdk.DefaultResourceLoader>[0]
        >,
      ) {
        super(options);
        for (const hook of options.extensionFactories ?? []) {
          const factory = typeof hook === "function" ? hook : hook.factory;
          this.binding ??= bindings.get(factory);
        }
      }
      async reload(): Promise<void> {
        await super.reload();
        const binding = this.binding;
        if (!binding?.permissionApi || !binding.wrapPermissionHandler) return;
        const result = this.getExtensions();
        const native = result.extensions.find(
          (extension) => extension.path === nativePath,
        );
        if (!native)
          throw new Error("Guard: native lifecycle hook is unavailable");
        const permissions = result.extensions.filter((extension) => {
          try {
            return realpathSync(extension.resolvedPath) === permissionPath;
          } catch {
            return false;
          }
        });
        if (permissions.length > 1)
          throw new Error("Guard: duplicate child permission instances");
        if (permissions.length) {
          for (const [event, handlers] of permissions[0].handlers)
            permissions[0].handlers.set(
              event,
              handlers.map((handler) => {
                const wrapped = binding.wrapPermissionHandler!(event, handler);
                return async (...args: unknown[]) =>
                  wrapped(args[0], args[1] as sdk.ExtensionContext | undefined);
              }),
            );
        } else {
          // No ambient/explicit provider: install one in the existing inline
          // hook, after discovery. Never instantiate a redundant permission node.
          await permissionSystem(binding.permissionApi);
        }
        // Acquire the child generation before permission publication. Keep
        // Nico's prompt runtime first and every other extension in stock order.
        const others = result.extensions.filter(
          (extension) => extension !== native,
        );
        const index = others[0]?.path === promptPath ? 1 : 0;
        others.splice(index, 0, native);
        result.extensions.splice(0, result.extensions.length, ...others);
      }
    },
  };
}
