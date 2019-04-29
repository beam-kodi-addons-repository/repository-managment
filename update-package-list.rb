#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'

require_relative 'tools'

GITHUB_USER = ENV['GITHUB_USER']
GITHUB_TOKEN = ENV['GITHUB_TOKEN']
GIT_USER_NAME = ENV['GIT_USER_NAME']
GIT_USER_EMAIL = ENV['GIT_USER_EMAIL']

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update-package-list [options]"
  opts.on("-u", "--packages-gh-user GH-REPO-USER") { |v| options[:package_list_user] = v }
  opts.on("-n", "--packages-gh-repo GH-REPO-NAME") { |v| options[:package_list_repository] = v }
  opts.on("-e", "--fetch-type FETCH-TYPE") { |v| options[:type] = v }
  opts.on("-r", "--repository GH-REPOSITORY", "GitHub repository name") { |v| options[:gh_repository] = v }
  opts.on("-t", "--tag GH-RELEASE-NAME", "GitHub release name") { |v| options[:gh_release] = v }
  opts.on("-s", "--sha GH-SHA", "GitHub commit SHA") { |v| options[:gh_sha] = v }
  opts.on("-f", "--file GH-RELEASE-FILE", "GitHub release filename") { |v| options[:gh_release_file] = v }
end.parse!

abort "Missing ENV GIT_USER_NAME for new commits" if GIT_USER_NAME.nil? || GIT_USER_NAME.empty?
abort "Missing ENV GIT_USER_EMAIL for new commits" if GIT_USER_EMAIL.nil? || GIT_USER_EMAIL.empty?
abort "Missing ENV GITHUB_USER for pushing and creating pull request" if GITHUB_USER.nil? || GITHUB_USER.empty?
abort "Missing ENV GITHUB_TOKEN for pushing and creating pull request" if GITHUB_TOKEN.nil? || GITHUB_TOKEN.empty?
abort "Missing fetch-type, use -e fetch type specify (gh-release or gh-repository)" unless options[:type]

abort "Missing repository user where is package list stored, use -u to spefify" unless options[:package_list_user]
abort "Missing repository name where is package list stored, use -n to spefify" unless options[:package_list_repository]

if options[:type] == "gh-release" # repository, release_name, file_name
  abort "Missing repository name for addon fetch, use -r to spefify" unless options[:gh_repository]
  abort "Missing repository release name for addon fetch, use -t to spefify" unless options[:gh_release]
  abort "Missing repository release file name for addon fetch, use -f to spefify" unless options[:gh_release_file]
  package_options = {type: "gh-release", github_repository: options[:gh_repository], github_release: options[:gh_release], github_filename: options[:gh_release_file] }
elsif options[:type] == "gh-repository" # repository, sha
  abort "Missing repository name for addon fetch, use -r to spefify" unless options[:gh_repository]
  abort "Missing repository commit SHA for addon fetch, use -s to spefify" unless options[:gh_sha]
  package_options = {type: "gh-archive", github_repository: options[:gh_repository], github_sha: options[:gh_sha] }
end

abort("Wrong fetch-type, don't know what to do") if package_options.nil?

addon_xml_path  = "addon.xml"
update_package_file_path = "updated-package-fetched.zip"

if options[:type] == "gh-release"
  $logger.info("Fetching addon package")
  fetch_release_file_from_github(package_options, update_package_file_path)
elsif options[:type] == "gh-repository"
  $logger.info("Fetching addon repository")
  git_repo = clone_github_repo_at_sha(package_options[:github_repository], package_options[:github_sha], "updated-package-repo")
  $logger.info("Creating addon package")
  git_archive(git_repo, "HEAD", update_package_file_path)
  $logger.info("Destroying addon repository")
  destroy_git_repo(git_repo)
end

$logger.info("Calculating file SHA256 hash")
package_options[:sha256] = sha256_file(update_package_file_path)
$logger.info("Extracting #{addon_xml_path}")
addon_xml_content = get_file_content_from_zip(update_package_file_path, addon_xml_path)
$logger.info("Parsing addons.xml")
addon_detail = get_addon_info_from_xml(addon_xml_content)
$logger.info("Removing addon package")
File.delete(update_package_file_path)

package_options.merge!(addon_detail)
$logger.info("Collected addon information #{package_options.inspect}")

$logger.info("Fetching current package list")
git_repo = clone_github_repo(options[:package_list_user], options[:package_list_repository], "master", "cloned-current-package-list")
package_file_path = "#{options[:package_list_repository]}/packages.yml"

$logger.info("Loading package list")
packages_content = load_package_list(package_file_path)

if packages_content.has_key?(package_options[:addon_id]) &&
  packages_content[package_options[:addon_id]][:sha256] == package_options[:sha256] &&
  packages_content[package_options[:addon_id]][:addon_version] == package_options[:addon_version]
  $logger.info("Package is same as deployed, nothing to do")
  $logger.info("Destroying packages list repository")
  destroy_git_repo(git_repo)
  exit 0
end
$logger.info("Updating package list")
packages_content = update_package_list(packages_content, package_options)

branch_name = "package-update-#{Time.now.to_i}"
$logger.info("Creating new branch #{branch_name}")
checkout_branch(git_repo, branch_name)

$logger.info("Saving package list")
write_package_list(package_file_path, packages_content)

$logger.info("Commiting changes")
commit_changes(git_repo, "#{addon_detail[:addon_id]} v#{addon_detail[:addon_version]}")

$logger.info("Pushing changes")
git_repo.push("origin", branch_name)

$logger.info("Destroying packages list repository")
destroy_git_repo(git_repo)

$logger.info("Creating pull request in GitHub")
create_github_pull_request(
    options[:package_list_user],
    options[:package_list_repository],
    "#{package_options[:addon_id]} v#{package_options[:addon_version]}",
    "#{package_options[:addon_id]} v#{package_options[:addon_version]}",
    branch_name,
    "master"
)
