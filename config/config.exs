import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://gitlab.com/jimsy/lamina",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  version_tag_prefix: "v"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
