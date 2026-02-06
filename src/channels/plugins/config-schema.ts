import * as ZodToJsonSchema from "zod-to-json-schema";

const zodToJsonSchema = (ZodToJsonSchema as any).zodToJsonSchema || (ZodToJsonSchema as any).default || ZodToJsonSchema;
import type { ZodTypeAny } from "zod";
import type { ChannelConfigSchema } from "./types.plugin.js";

export function buildChannelConfigSchema(schema: ZodTypeAny): ChannelConfigSchema {
  return {
    schema: zodToJsonSchema(schema, {
      target: "draft-07",
    }) as Record<string, unknown>,
  };
}
