# QueueManager

QueueManager is the text-mode operational front end for bashqueues.

The supported manager is the Python panel manager. The legacy numbered text menu has been removed.

It is intentionally separate from the core engine:

```text
queuebash.sh        core queue engine
queuemgr.sh         compatibility shim to the panel manager
queuemgr_panel.py   panel manager
```

## Launch

```bash
queue mgr
queue manager
queue qm
```

## Panels

```text
Queue Users
Jobs
Drafts
Classes
Modules
Assets
Maintenance
Exceptions
Class Creator
Task Creator
```

The Restriction Builder panel is temporarily removed. Class restriction records are managed through Classes/Class Creator commands and module/asset documentation until the builder is redesigned.

The footer reserves separate rows for menu/help keys and status/message text so the two lines do not overlap.


## Panel command line and function keys

The Python QueueManager panel supports an AS/400-style command line.  Type any printable command character while the panel is open and the footer command prompt opens with that character already entered.  `F2` opens the same command prompt with an empty line.

Command words use the same resolver as panel fields: exact match, first unique letters, and unique substring matching.  This means short forms are accepted when they are unambiguous.

Examples:

```text
jo                         switch to Jobs
tas                        switch to Task Creator
user hc3                   select queue owner hc3
user clear                 return to current/default queue owner
task name publish_git      open Task Creator and set the job name
task command bash publish_to_github.sh
task class GITHUB          set Task Creator class using unique class prefix/substr
task priority 5
task schedule +1h
task preview
task save
class GITHUB               switch to Classes and select the matching class
class use GITHUB           set the matching class into Task Creator
cla mycla hist             switch to Classes, select unique class match, show history/backups
panel:classes              jump directly to the Classes panel
maint health preview       select the maintenance health recipe and show preview
draft load DRAFT-...       select a draft and run the draft load action
job 1798231 history         select the job whose QID contains 1798231 and show history
history 1798231             same job-history shortcut
```

Press `*` in the command line to open contextual command completions.  On Queue Users this offers known users and `panel:*` jumps.  Selecting `panel:classes` leaves that expanded command in the command line; pressing `*` again then offers classes and class actions.  For example, the operator can build `class MYCLASS history` from successive `*` selections, or type `cla mycla hist` directly from any panel.


### Asset and class actions from the panel command line

Actions for Classes and Assets are available through `F2` command entry, not only through `F10` prompts. When the cursor is on the Classes panel, bare commands apply to the selected class:

```text
explain
history
enable
disable
refresh
use
```

When the cursor is on the Assets panel, bare commands apply to the selected asset/facility:

```text
explain
hint
validate
enable
disable
refresh
rollback
```

The same actions can be typed explicitly from any panel:

```text
class GITHUB_PUBLISH history
class GITHUB_PUBLISH disable
asset net:allowance explain
asset net:allowance disable
```

`*` completion follows the same rule: object/action choices appear first for the current Classes or Assets panel, and `panel:*` navigation choices stay at the bottom.
The popup is ordered for work first and navigation second: object/action completions first, user choices where relevant after that, and panel jumps at the bottom.  This means Jobs starts with job commands, Classes starts with class commands, Maintenance starts with maintenance recipes, and `panel:*` destinations remain discoverable without taking over the top of the list.

Panel tabs are hotkey-labelled rather than numbered.  The labels show the portable typed hotkeys: `[U]` Queue Users, `[J]` Jobs, `[D]` Drafts, `[C]` Classes, `[O]` Modules, `[A]` Assets, `[M]` Maintenance, `[E]` Exceptions, `[K]` Class Creator, and `[T]` Task Creator.  Number keys are no longer used for panel selection.

Normal letter keys are therefore reserved for typed commands.  Global panel actions have function-key bindings:

```text
F1   Help
F2   Command line
F3   Queue Users
F4   Jobs
F5   Refresh
F6   Toggle dry-run
F7   Filter
F8   Next detail tab
F9   intentionally unbound; use typed command `job FRAG copy`
F10  Action on selected row
F11  intentionally unbound on Linux desktops
F12  Quit, with Esc as the portable quit key
```

Job commands can include a QID fragment.  For example, `job 1798231 history` switches to Jobs, finds the single visible job whose QID/label/command contains `1798231`, selects it, switches the right-hand detail tab to History, and shows the history output in the right-hand detail pane.  If the fragment is ambiguous, the panel reports the number of matches rather than guessing.

Job mutation commands are also typed commands. On the Jobs panel, the selected job is the implicit object, so these are valid:

```text
change priority 5
kill
delete
undelete
edit
```

The explicit forms are also valid from any panel:

```text
job 1798231 change priority 5
job 1798231 kill
job 1798231 delete
job 1798231 undelete
job 1798231 edit
```

`job edit` is deliberately implemented as cancel then new draft. It confirms the operation, cancels the selected job, and then populates the Task Creator draft from the job metadata. The replacement task can then be reviewed, saved, dry-run, or submitted normally.

Some Linux terminals/window managers intercept particular function keys, especially higher keys and full-screen/window-management combinations.  F11 is deliberately not used by the panel because many Linux desktops bind it to full-screen.  Exception actions are therefore available through typed commands such as `ex`, `exception`, `ce`, and `clear-exception` rather than through F11.  The panel keeps everything typeable through the command line as the reliable fallback.  Terminals that expose F13-F24 or Alt-Fn can map those extended keys later without changing the command grammar.

## Panel field selection

Panel action prompts and selectable fields share the same resolver.

Supported entry behaviour:

```text
blank       keep the current/default value
current     clear optional user/delegation fields back to current/default
none        clear optional user/delegation fields back to current/default
clear       clear optional user/delegation fields back to current/default
-           clear optional user/delegation fields back to current/default
number      select that numbered entry from the available values
unique text first unique letters of a command or value
partial     unique substring of a command or value
*           open the searchable scrollable selection list
```

Inside the `*` selection list, type any part of the value to filter the list, use Up/Down or PgUp/PgDn to move the highlighted row, and press Enter to select it. Esc or q cancels.

This behaviour is used by action prompts and by panel fields that have known values, including Task Creator class selection, runner selection, state filters, queue clear targets, draft actions, class actions, asset actions, record actions, user fields, and confirmations. Optional user fields can always be cleared back to current/default by entering `current`, `none`, `clear`, `default`, or `-`, or by opening `*` and choosing `<current/default>`.

For example, in Task Creator class selection:

```text
*       opens the class list
1       selects the first class
pub     selects PUBLISH if that is unique
git     selects a class containing git if that substring is unique
```


## Task Creator drafts

Task Creator is a working editor for one task at a time. It supports:

```text
preview   show the generated queue submit command
dryrun    show what would be submitted without writing a job
save      write the current task to persistent queue draft storage
submit    submit the task as a queue job
clear     clear the working Task Creator draft
```

Task Creator includes the safety-critical job orchestration fields that are normally easy to forget on the shell command line:

```text
dependencies       queue submit --after-success / --depends-on
inherit env from   queue submit --inherit-env-from
on success hook    queue submit --on-success
on failure hook    queue submit --on-failure
on retry hook      queue submit --on-retry-failure
```

Typed command examples:

```text
task dependencies 20260524_abc123, setup_job
task inherit setup_job
task on-success bash -c 'echo completed'
task on-failure bash -c 'echo failed'
task on-retry-failure bash -c 'echo attempt failed'
```

`save` uses `queue draft create` and does not submit anything. The saved draft appears in the Drafts panel and can later be loaded, readied, submitted, or abandoned.

After a successful non-dry-run `submit`, the Task Creator working draft is cleared automatically. This makes repeated submits deliberate rather than accidental. Dry-run submit keeps the draft.


When launched from a sourced `queuebash.sh`, closing the panel returns to the caller shell. The queue manager launcher must not use `exec` to replace the current shell.

The manager mostly routes to existing trusted commands:

```bash
queue list
queue show
queue explain
queue assets
queue assets explain
queue classes list
queue classes explain
queue health
queue dispatch-trace
```

## Scriptable class creation

```bash
queue mgr class-create CLASS \
  --no-parallel \
  --max-concurrent 1 \
  --exclusive-claim some:claim \
  --shared-asset family check "target" key=value \
  --exclusive-asset family check "target" key=value
```

The output class uses record format only:

```bash
queue_class_shared_asset net http_status "https://github.com" timeout=5
queue_class_exclusive_claim "github_publish:slot"
```

Legacy `CLASS_SHARED_ASSETS`, `CLASS_EXCLUSIVE_ASSETS`, and `CLASS_ASSETS` are not generated.


## Asset hints

QueueManager can show target and parameter hints:

```bash
queue mgr hints
queue mgr hint net:http_status
queue mgr hint runnable:script
queue mgr picker
```

Interactive class creation also supports `?` at the asset-family prompt.

Hints are advisory and do not replace plugin contract validation. Plugins remain the source of truth for whether an asset check passes.


## Plugin-published hints

QueueManager hinting is driven by asset helpers.

A helper may define:

```bash
queue_asset_hints() {
    cat <<'EOF'
net:http_status	target=URL or host	params=timeout=5	example=queue_class_shared_asset net http_status "https://github.com" timeout=5	notes=Checks HTTP status.
EOF
}
```

Fields are tab-separated. Supported metadata keys are `target`, `params`, `example`, and `notes`.


## Network allowance hint

The canonical charged-link preflight facility is `net:allowance`:

```bash
queue_class_shared_asset net allowance "wwan0" allowance_bytes=10G direction=rx_tx
```

## Selected queue-user context

The command-line queue-user selector supports both selection-only and one-shot forms:

```bash
queue --queue-user USER
queue user USER
queue --queue-user USER list
queue user USER list
```

The selection-only form updates the effective queue user for the current sourced shell session. Later commands such as `queue list` continue to use that selected queue root until another queue user is selected, the Queue Users panel clear/current entry is selected, or the shell environment is reset.

When a selected queue user is active, list output prints a visible context banner before the job table, for example:

```text
QUEUE USER: hc3  shell-user=root  root=/home/hc3/.queuebash
```

This makes it explicit that the operator is viewing or mutating another user's queue.


## 0.16.12 panel user-selection notes

The Queue Users panel has a clear/current row. Selecting it removes the panel queue-owner override and returns all panels to the current/default queue root.

Task Creator `submit user` is separate from queue owner selection. It is only Unix-user delegation. For normal user operation, leave it blank/current. Enter `current`, `none`, `clear`, `default`, or `-` to clear it. A non-root user submitting as themselves will no longer generate `runuser`; only root/operator delegation to another Unix account uses `runuser`.

## 0.16.13 selected-user panel lifecycle note

When root/operator has selected another queue user, `queue mgr` opens the panel in the current operator/root shell. It must not delegate the whole panel process to the selected queue owner and must not replace the current shell with `runuser` or `sudo`.

Panel actions that evaluate queue-local code still invoke guarded queue commands separately. Those action-level commands may delegate to the queue owner, but delegation returns to the original panel/operator shell when complete.

## Maintenance panel

The Python panel manager includes a **Maintenance** view for the tidy-up and recovery commands that are too easy to run hastily from a shell prompt:

- `queue health --fix`
- `queue compress-logs`
- `queue clean-logs ...`
- `queue clear deleted`
- `queue clear done`
- `queue clear interrupted`
- `queue clear cancelled`

The default action is **queue**, not direct execution.  Selecting `queue` submits a normal queue job using the `QUEUE_MAINTENANCE` class, a conservative priority, a bounded log size, and a not-before delay such as `+10m`, `+30m`, or `+1h`.  This keeps maintenance work audited, visible in `queue list`, and cancellable before it runs.

The Maintenance action prompt supports the same panel field behaviour as the rest of the UI: first unique letters, unique substrings, numeric selection, and `*` for a searchable list.

Available Maintenance actions:

```text
queue     submit the selected maintenance recipe as a queue job
direct    run the selected queue command immediately in the panel/operator process
preview   show both queued and direct command previews
schedule  edit the not-before delay for this recipe
priority  edit queued job priority
command   edit the queue command arguments for this recipe
reset     restore the recipe defaults
```

The `direct` action is deliberately separate and asks for confirmation.  It is intended for urgent recovery only.  Routine fixes, log rolling, and deletes should be queued so the normal queue policy, class checks, logs, and audit trail apply.

The Maintenance view is an operator UI.  If a queue owner is selected in the Queue Users panel, queued maintenance jobs are submitted into that selected queue root.  The payload command also includes the selected queue user so a root/operator-created maintenance job continues to target the intended queue.

## 0.16.14 legacy manager cleanup

The old readline/text QueueManager REPL has been physically removed.  These internal functions are no longer present:

```text
_queuemgr_print_commands
_queue_legacy_queuemgr
_queuemgr_repl_complete
```

Supported manager entry points are now panel-only:

```bash
queue mgr
queue mgr panel
queue manager
queuemgr
```

`queue legacy-manager` remains blocked and reports that the legacy manager was removed.

### Right-hand command output modes

Typed output commands update the right-hand detail panel instead of opening a transient popup.  The selected mode remains active while the operator moves through the list, so `job 1798231 history` selects the matching job, switches Jobs detail to History, and then Up/Down shows History for the newly selected job.  Likewise, `job 1798231 explain`, `job 1798231 exception`, and `job 1798231 show` switch to Explain, Exceptions, or Log respectively.

Class commands follow the same rule.  `class MYCLASS history` selects the class and switches the Classes right-hand pane to History.  Moving Up/Down through classes keeps the History pane active.  `class MYCLASS explain`, `show`, and `validate` switch the class right-hand pane to those modes.

F9 is deliberately not a job-copy function.  Copying a job into Task Creator is a typed command: `job QID-FRAGMENT copy`.  This avoids accidental mutation from function keys.

Examples:

```text
job FRAG history
job FRAG explain
job FRAG exception
class NAME history
```

### Task Creator context commands

When the panel is already on Task Creator, bare task actions apply to the current task draft.
For example, typing:

```text
submit
```

is interpreted as:

```text
task submit
```

The same current-task shorthand applies to `save`, `preview`, `dryrun`, `clear`, and task field edits.
This keeps the editor behaviour object-oriented: `(this task) submit`, rather than forcing the operator to repeat the noun every time.

### 0.16.24 job tail right-hand pane

`job FRAG tail` now selects the matching job and switches the right-hand pane to a dedicated **Tail** mode. This is separate from **Log**, which continues to show the full `queue show` output.

While the Jobs panel is in Tail mode, moving up or down through the job list keeps the right-hand pane in Tail mode and shows the tail for the newly selected job.

### 0.16.28 Modules panel and reverse panel navigation

The panel now includes a **Modules** view for managing all installed module families:

- `classes/*.env`
- `assets.d/*.sh`
- `caps.d/*.sh`

This is where cap modules such as `billing` and `net_usage` are managed. The Modules panel supports explain, refresh, enable, and disable actions. Disabled modules are moved under the relevant `.disabled/` directory and are skipped by the normal loader.

Typed examples:

```text
module class GITHUB_PUBLISH disable
module class GITHUB_PUBLISH enable
module asset net disable
module asset net enable
module cap billing disable
module cap billing enable
module refresh cap caps.d
```

The shorter cap-oriented form also works:

```text
cap billing disable
cap net_usage explain
```

Panel navigation:

```text
Tab        next panel
Shift-Tab  previous panel
```


### Task Creator queue-reference fields

`after success deps` and `inherit env from` use the panel chooser model. Press `*` to list known queue job names/QIDs and a clear option. Selecting clear empties the field. A typed unique job name/QID fragment is resolved when possible; manual comma/space-separated dependency lists are still accepted.


### Class Creator restriction builder

The Class Creator owns restriction-building workflow.  The old standalone
Restriction Builder panel remains removed from active panel order, but class
records can be created from hints while editing a class.

On the Class Creator panel, select **add restriction** or use the F2 command
line:

```text
classcreator restriction net:allowance
restriction billing
restriction cap:net_usage
```

The prompts follow the standard panel field rules:

- `*` opens the relevant chooser.
- First unique letters or unique substrings resolve a value.
- Facility selection lists asset facilities and cap modules.
- Target selection offers common queue variables such as
  `${QUEUEBASH_COMMAND_ARG_1_ABSPATH}`, `${QUEUEBASH_JOB_WORKDIR}`, `${JOB_ID}`
  and `${QUEUEBASH_ROOT}`.
- Parameter selection offers examples, while still allowing free-form
  `key=value` text based on the displayed hint.

The selected asset/cap hint is shown before the target/parameter prompts, so
class restrictions can be built from the documented contract rather than from
memory.  Generated records are appended to the class draft only after
confirmation.

### 0.16.33 stale asset-side net_usage cleanup

`net_usage` is a cap module, not an asset module. The Modules panel now hides stale
`asset:net_usage` entries from older queue roots, and `queue modules list` triggers
a best-effort prune of obsolete asset-side `net_usage.sh` into
`assets.d/.obsolete/` when permissions allow.

`queue modules explain cap:NAME` reads the active cap module first. It only falls
back to `caps.d/.disabled/NAME.sh` when the active module is absent.

### 0.16.33 Class Creator hint-driven parameter prompts

Class Creator restriction setup now reads asset/cap hint metadata and turns it into prompts. For example, choosing `time:window` asks for the policy target and then prompts for `weekdays`, `weekday_windows`, `weekends`, `weekend_windows`, and optional `now_epoch` separately.

Each generated prompt supports the standard panel field behaviour: `*` opens the contextual chooser, unique prefixes/substring matches resolve values, blank/clear omits optional values, and free text is allowed where the hint requires an operator-specific value.

### 0.16.33 Exceptions panel and selected queue owners

When root/operator selects another queue owner, the panel must not read exception
files directly from the operator process `QUEUEBASH_ROOT`.  The Exceptions panel
now uses:

```bash
queue exception list-all
```

through the normal panel `qrun()` path, so `--queue-user USER` is honoured in the
same way as the Jobs pane.  The Jobs right-hand `Exceptions` detail and the
Exceptions top-level panel should therefore show the same queue owner's exception
overlays.

The header root display also follows the selected owner, avoiding misleading
output such as owner `testu` with root `/root/.queuebash`.

### 0.16.33 Exceptions panel and selected queue owners

When root/operator selects another queue owner, the panel must not read exception
files directly from the operator process `QUEUEBASH_ROOT`.  The Exceptions panel
now uses:

```bash
queue exception list-all
```

through the normal panel `qrun()` path, so `--queue-user USER` is honoured in the
same way as the Jobs pane.  The Jobs right-hand `Exceptions` detail and the
Exceptions top-level panel should therefore show the same queue owner's exception
overlays.

The header root display also follows the selected owner, avoiding misleading
output such as owner `testu` with root `/root/.queuebash`.

### Class Creator restriction prompt quality

Class Creator builds restriction records from the hints exported by `assets.d` and `caps.d` modules. The wizard must ask field-specific questions rather than exposing a single raw parameter string.

For example, `time:window` should ask for the policy name, weekday set, weekday windows, weekend set, and weekend windows. Test-only controls such as `now_epoch=TEST` must not be offered as normal production fields.

For `runnable:filesystem`, the prompt labels executable as executable/searchable/traversable. This matters for directories: `/tmp` is normally writable and traversable, so a directory gate should normally use `executable=1` or omit the executable check, not `executable=0`.


Module commands also accept completion-expanded identities, for example:

```bash
class:CAPS_TEST explain
asset:net explain
cap:net_usage explain
```

In these forms the first token is the module identity and the following token is the action.

## Global Resources panel

The `Global Resources` panel shows explicit cross-user global claims created by `queue_class_global_*` class records.

It displays claim key, mode, slot usage, and holders. Useful typed commands from F2:

```text
global claims
global claim github:publish
global cleanup --dryrun
global health
```

Global resources are opt-in. Normal class assets remain local to the selected queue root.

## Cron bridge visibility

The optional cron bridge submits scheduled entries as normal queue jobs. In the
panel they appear as jobs named `cron_<hash>` and use generated classes of the
same name. This makes cron firings visible in Jobs, Logs, History, Tail, and
Exception views instead of hiding them inside the system cron daemon.

Use the F2 command line for:

```text
cron list
cron root
cron tick --dryrun
```

## Task/Class sandbox fields

Task Creator exposes a sandbox override field. Class Creator exposes a default sandbox field which renders `CLASS_DEFAULT_SANDBOX_LEVEL`. Valid values are blank/off, `network-none`, `restrict-egress`, and `strict`.

The F2 command line accepts current-task and current-class forms such as:

```text
task sandbox network-none
class sandbox strict
```

### 0.17.14 systemd relative executable handling

When the systemd runner is selected, bashqueues now normalises a relative executable argv[0] such as `./script.sh` to an absolute path before passing it to `systemd-run`. This avoids systemd's `is neither a valid executable name nor an absolute path` launch failure while keeping the job working directory unchanged.


### 0.17.17 Class Creator seccomp policy chooser

The Queue Manager Class Creator exposes both sandbox and seccomp policy fields. Use `*` on the default seccomp field to choose from `queue policies list seccomp`. F2 commands include `classcreator seccomp docker-default` and `classcreator seccomp-allow @debug`.

### 0.17.18 Queue Manager class edit safety

The Queue Manager class edit action is noninteractive. Selecting `edit` on a class now loads the selected class into the Class Creator panel, where it can be previewed, changed, validated, and saved. The panel no longer invokes `$EDITOR` through `queue classes edit`, because interactive editors can block the curses UI.
