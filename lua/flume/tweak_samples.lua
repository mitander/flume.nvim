-- Self-contained reading fixtures, not application code or parser substitutes.
return {
    {
        name = "queue.lua",
        filetype = "lua",
        language = "lua",
        code = [[local Queue = {}
Queue.__index = Queue

-- Keep one pending update per project, preserving arrival order.
function Queue.new(limit)
    return setmetatable({ limit = limit, items = {}, pending = {} }, Queue)
end

function Queue:push(project, callback)
    if self.pending[project] then
        return false, "update already queued"
    end
    assert(#self.items < self.limit, "queue is full")
    self.pending[project] = true
    self.items[#self.items + 1] = { project = project, callback = callback }
    return true
end

function Queue:drain()
    for index, item in ipairs(self.items) do
        local ok, result = pcall(item.callback, item.project)
        self.pending[item.project] = nil
        if not ok then
            print(string.format("update %d failed: %s", index, result))
        end
    end
    self.items = {}
end

return Queue]],
    },
    {
        name = "dispatch.rs",
        filetype = "rust",
        language = "rust",
        code = [[use std::collections::BTreeMap;
use std::path::PathBuf;

const MAX_PENDING: usize = 64;

#[derive(Debug, Clone)]
struct Request {
    project: PathBuf,
    command: String,
    attempts: u8,
}

// Failed work stays available for an explicit retry.
fn dispatch(pending: &mut BTreeMap<u64, Request>, id: u64) -> Result<String, String> {
    if pending.len() > MAX_PENDING {
        return Err("too many pending requests".into());
    }
    let request = pending.get_mut(&id).ok_or("request not found")?;
    request.attempts += 1;
    let title = format!("{}: {}", request.project.display(), request.command);

    match request.attempts {
        1..=3 => Ok(title),
        _ => Err(format!("retry limit reached for {id}")),
    }
}
]],
    },
    {
        name = "inventory.py",
        filetype = "python",
        language = "python",
        code = [[from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Entry:
    path: Path
    size: int
    ignored: bool = False


def summarize(entries: list[Entry], limit: int = 4096) -> dict[str, int]:
    """Count visible bytes by extension without modifying the inventory."""
    totals: dict[str, int] = {}
    for entry in entries:
        if entry.ignored or entry.size < 0:
            continue
        extension = entry.path.suffix.lower() or "<none>"
        totals[extension] = totals.get(extension, 0) + entry.size
        if len(totals) > limit:
            raise ValueError(f"too many file types: {len(totals)}")
    return dict(sorted(totals.items()))


example = Entry(Path("src/catalog.py"), size=128)
print(summarize([example]))]],
    },
    {
        name = "request.ts",
        filetype = "typescript",
        language = "typescript",
        code = [[type Reply<T> = { value: T; revision: number };

interface RequestOptions {
  readonly signal: AbortSignal;
  attempts?: number;
}

// Retry transient failures, but never hide cancellation.
export async function request<T>(
  url: URL,
  options: RequestOptions,
): Promise<Reply<T>> {
  const attempts = options.attempts ?? 3;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    options.signal.throwIfAborted();
    const response = await fetch(url, { signal: options.signal });
    if (response.ok) {
      const revision = Number(response.headers.get("x-revision") ?? "0");
      return { value: (await response.json()) as T, revision };
    }
    if (response.status < 500) {
      throw new Error(`Request rejected: ${response.status}`);
    }
  }
  throw new Error(`No response after ${attempts} attempts`);
}]],
    },
    {
        name = "workspace.tsx",
        filetype = "typescriptreact",
        language = "tsx",
        code = [[import type { ReactNode } from "react";

type Workspace = {
  id: string;
  name: string;
  active: boolean;
  children?: ReactNode;
};

export function WorkspaceList({ items }: { items: readonly Workspace[] }) {
  const visible = items.filter((item) => item.name.trim().length > 0);

  return (
    <section aria-label="Workspaces">
      <h2>Open projects <span>{visible.length}</span></h2>
      {visible.map(({ id, name, active, children }) => (
        <article key={id} data-active={active}>
          <button type="button" disabled={!active}>
            {name || "Untitled"}
          </button>
          {/* Details remain secondary to the project name. */}
          <small>{children ?? "No running commands"}</small>
        </article>
      ))}
    </section>
  );
}]],
    },
    {
        name = "buffer.zig",
        filetype = "zig",
        language = "zig",
        code = [[const std = @import("std");

const Buffer = struct {
    bytes: []u8,
    used: usize = 0,

    const Error = error{NoSpaceLeft};

    /// Append a whole record or leave the buffer unchanged.
    fn append(self: *Buffer, record: []const u8) Error!void {
        if (record.len > self.bytes.len - self.used) {
            return error.NoSpaceLeft;
        }
        @memcpy(self.bytes[self.used..][0..record.len], record);
        self.used += record.len;
    }
};

test "append preserves records" {
    var storage: [128]u8 = undefined;
    var buffer: Buffer = .{ .bytes = &storage };
    try buffer.append("project: ready\n");
    try std.testing.expectEqualStrings("project: ready\n", buffer.bytes[0..buffer.used]);
}]],
    },
    {
        name = "catalog.go",
        filetype = "go",
        language = "go",
        code = [[package catalog

import (
    "context"
    "fmt"
    "sort"
)

type Project struct {
    Name   string
    Root   string
    Active bool
}

// Names returns a stable view without changing the shared catalog.
func Names(ctx context.Context, projects map[string]Project) ([]string, error) {
    names := make([]string, 0, len(projects))
    for id, project := range projects {
        if err := ctx.Err(); err != nil {
            return nil, fmt.Errorf("read project %q: %w", id, err)
        }
        if project.Active && project.Root != "" {
            names = append(names, project.Name)
        }
    }
    sort.Strings(names)
    return names, nil
}]],
    },
}
