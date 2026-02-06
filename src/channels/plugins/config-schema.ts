import { zodToJsonSchema } from "zod-to-json-schema";
import type { ZodTypeAny } from "zod";
import type { ChannelConfigSchema } from "./types.plugin.js";

export function buildChannelConfigSchema(schema: ZodTypeAny): ChannelConfigSchema {
  return {
    schema: zodToJsonSchema(schema, {
      target: "draft-07",
    }) as Record<string, unknown>,
  };
}
