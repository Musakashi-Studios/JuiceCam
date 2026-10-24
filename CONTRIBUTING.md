# Contributing to JuiceCam

JuiceCam is built in the open, and contributions to the plugin, documentation, and demo are welcome. If you are planning a larger change, open an issue first so we can agree on the behavior before you spend time implementing it.

## Set up the project

1. Install Godot 4.7, the version targeted by this demo project.
2. Clone this repository and open its root folder in Godot. The root is the demo project.
3. Run the main scene to explore the demo. The plugin source is in `addons/juicecam`; the demo scenes are in `JuiceCamDemo`.

## Make a change

- Keep pull requests focused on one fix or feature.
- Update the plugin guide or demo when the change affects user-facing behavior.
- Keep the plugin self-contained in `addons/juicecam`. Put demo-only content in `JuiceCamDemo`.
- Avoid committing `.godot` cache files, exported builds, credentials, or unrelated game assets.
- For a new public feature, describe the use case and how users will configure or call it.

## Check your change

Open the project in Godot and run the demo for changes that affect scenes, the Inspector, or camera behavior. Include the checks you ran in your pull request description.

## Open a pull request

Link the issue your change addresses, explain what changed and why, and include the checks you ran. Add screenshots for visible changes.

For bug reports and feature discussions, see [ISSUES.md](ISSUES.md). To create a custom camera add-on without changing JuiceCam itself, see the [custom add-on guide](docs/creating-addons.md).
