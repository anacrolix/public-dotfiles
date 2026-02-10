#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone, timedelta

USERNAME = "anacrolix"
BRANCH_PREFIX = f"{USERNAME}/"
MERGE_AGE_CUTOFF = timedelta(weeks=1)

GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
BLINK_GREEN = "\033[5;32m"
RESET = "\033[0m"


PR_FRAGMENT = """
fragment PrFields on SearchResultItemConnection {
  nodes {
    ... on PullRequest {
      number
      title
      headRefName
      state
      isDraft
      closedAt
      mergedAt
      updatedAt
      reviewDecision
      autoMergeRequest { enabledAt }
      repository { nameWithOwner }
      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              contexts(first: 50) {
                nodes {
                  ... on CheckRun {
                    name
                    status
                    conclusion
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
"""


def make_batch_query(search_filters):
    aliases = []
    for i, sf in enumerate(search_filters):
        aliases.append(
            f'  q{i}: search(query: "{sf}", type: ISSUE, first: 50) {{ ...PrFields }}'
        )
    return PR_FRAGMENT + "{\n" + "\n".join(aliases) + "\n}"


verbose = False


def run_batch_query(search_filters):
    query = make_batch_query(search_filters)
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
    if verbose:
        print(f"[api] batch query with {len(search_filters)} searches", file=sys.stderr)
    result = subprocess.run(cmd, capture_output=True, text=True)
    if verbose:
        print(f"[api] status: {result.returncode}, {len(result.stdout)} bytes", file=sys.stderr)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    data = json.loads(result.stdout)["data"]
    all_nodes = []
    for i in range(len(search_filters)):
        nodes = data[f"q{i}"]["nodes"]
        if verbose:
            print(f"[api]   q{i}: {len(nodes)} PRs ({search_filters[i]})", file=sys.stderr)
        all_nodes.extend(nodes)
    return all_nodes


def time_ago(dt, now):
    delta = now - dt
    days = delta.days
    hours = delta.seconds // 3600
    if days > 0:
        return f"{days}d {hours}h ago"
    mins = (delta.seconds % 3600) // 60
    if hours > 0:
        return f"{hours}h {mins}m ago"
    return f"{mins}m ago"


def osc8(url, text):
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"


def summarize_checks(pr):
    try:
        nodes = pr["commits"]["nodes"][0]["commit"]["statusCheckRollup"]["contexts"][
            "nodes"
        ]
    except (IndexError, KeyError, TypeError):
        return "No checks"
    running = succeeded = failed = queued = 0
    for c in nodes:
        status = c.get("status", "")
        conclusion = c.get("conclusion", "")
        if status == "COMPLETED":
            if conclusion in ("FAILURE", "TIMED_OUT", "CANCELLED"):
                failed += 1
            else:
                succeeded += 1
        elif status == "IN_PROGRESS":
            running += 1
        elif status == "QUEUED":
            queued += 1
    parts = []
    if running:
        parts.append(f"{running} running")
    if queued:
        parts.append(f"{queued} queued")
    if failed:
        parts.append(f"{failed} failed")
    if succeeded:
        parts.append(f"{succeeded} passed")
    return ", ".join(parts) or "No checks"


def process_pr(pr, now, cutoff):
    branch = pr["headRefName"]
    state = pr["state"]
    review = pr.get("reviewDecision") or "NONE"
    merged_at = pr.get("mergedAt")
    merged_dt = (
        datetime.fromisoformat(merged_at.replace("Z", "+00:00")) if merged_at else None
    )

    if state == "MERGED" and merged_dt and merged_dt < cutoff:
        return None

    closed_at = pr.get("closedAt")
    if state == "CLOSED" and closed_at:
        closed_dt = datetime.fromisoformat(closed_at.replace("Z", "+00:00"))
        if closed_dt < cutoff:
            return None

    updated_at = pr.get("updatedAt")
    updated_dt = (
        datetime.fromisoformat(updated_at.replace("Z", "+00:00")) if updated_at else datetime.min.replace(tzinfo=timezone.utc)
    )

    return {
        "number": pr["number"],
        "title": pr["title"],
        "branch": branch,
        "repo": pr["repository"]["nameWithOwner"],
        "state": state,
        "is_draft": pr.get("isDraft", False),
        "merged_dt": merged_dt,
        "updated_dt": updated_dt,
        "review": review,
        "auto_merge": bool(pr.get("autoMergeRequest")),
        "workflows": summarize_checks(pr),
    }


def main():
    global verbose
    parser = argparse.ArgumentParser(description="Show PR status table")
    parser.add_argument("-v", "--verbose", action="store_true", help="Log API calls to stderr")
    args = parser.parse_args()
    verbose = args.verbose

    now = datetime.now(timezone.utc)
    cutoff = now - MERGE_AGE_CUTOFF
    cutoff_date = cutoff.strftime("%Y-%m-%d")

    # Split queries by state so each stays well under the 50-result cap.
    # All searches are batched into a single GraphQL request using aliases.
    search_filters = []
    for owner_filter in [f"head:{BRANCH_PREFIX}", f"assignee:{USERNAME}"]:
        base = f"is:pr {owner_filter}"
        search_filters.append(f"{base} is:open")
        search_filters.append(f"{base} is:merged merged:>={cutoff_date}")
        search_filters.append(f"{base} is:closed -is:merged closed:>={cutoff_date}")
    all_prs = run_batch_query(search_filters)

    # Deduplicate by PR number+repo
    seen = set()
    rows = []
    for pr in all_prs:
        key = (pr["repository"]["nameWithOwner"], pr["number"])
        if key in seen:
            continue
        seen.add(key)
        row = process_pr(pr, now, cutoff)
        if row:
            rows.append(row)

    rows.sort(
        key=lambda r: (0 if r["merged_dt"] else 1, r["updated_dt"]),
        reverse=True,
    )

    headers = ["Repo", "PR", "Branch", "Title", "Status", "Workflows"]
    max_title = 60

    def make_status(r, now):
        if r["state"] == "MERGED":
            return f"merged {time_ago(r['merged_dt'], now)}", True
        parts = []
        if r["is_draft"]:
            parts.append("draft")
        if r["state"] == "CLOSED":
            parts.append("closed")
            return ", ".join(parts), False
        approved = r["review"] == "APPROVED"
        if approved:
            parts.append("approved")
        else:
            parts.append("needs review")
        if approved and r["auto_merge"]:
            parts.append("auto merge")
        elif approved and not r["auto_merge"]:
            parts.append("no auto merge")
        return ", ".join(parts), approved

    visible = []
    status_approved = []
    for r in rows:
        title = (
            r["title"][: max_title - 3] + "..."
            if len(r["title"]) > max_title
            else r["title"]
        )
        status_text, is_approved = make_status(r, now)
        status_approved.append(is_approved)
        visible.append([
            r["repo"],
            f"#{r['number']}",
            r["branch"],
            title,
            status_text,
            r["workflows"],
        ])

    widths = [len(h) for h in headers]
    for v in visible:
        for i, cell in enumerate(v):
            widths[i] = max(widths[i], len(cell))

    def pad(text, width):
        return text + " " * (width - len(text))

    pr_idx = 1
    status_idx = 4
    workflows_idx = 5

    print(" | ".join(pad(h, widths[i]) for i, h in enumerate(headers)))
    print("-+-".join("-" * w for w in widths))

    for r, v, approved in zip(rows, visible, status_approved):
        url = f"https://github.com/{r['repo']}/pull/{r['number']}"

        cells = []
        for i in range(len(v)):
            if i == pr_idx:
                cells.append(osc8(url, v[i]) + " " * (widths[i] - len(v[i])))
            elif i == status_idx and not approved and r["state"] == "OPEN":
                cells.append(f"{YELLOW}{pad(v[i], widths[i])}{RESET}")
            elif i == status_idx and approved:
                wf = r["workflows"]
                stuck = (r["state"] == "OPEN"
                         and "failed" not in wf and "running" not in wf
                         and "queued" not in wf and wf != "No checks")
                color = BLINK_GREEN if stuck else GREEN
                cells.append(f"{color}{pad(v[i], widths[i])}{RESET}")
            elif i == workflows_idx and r["state"] != "MERGED" and r["workflows"] != "No checks":
                wf = r["workflows"]
                if "failed" in wf:
                    color = RED
                elif "running" in wf or "queued" in wf:
                    color = YELLOW
                else:
                    color = GREEN
                cells.append(f"{color}{pad(v[i], widths[i])}{RESET}")
            else:
                cells.append(pad(v[i], widths[i]))

        print(" | ".join(cells))


if __name__ == "__main__":
    main()
