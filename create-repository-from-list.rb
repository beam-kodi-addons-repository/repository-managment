#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'optparse'

require_relative 'tools'
require 'fileutils'
require 'rexml/document'

GITHUB_USER = ENV['GITHUB_USER']
GITHUB_TOKEN = ENV['GITHUB_TOKEN']
GIT_USER_NAME = ENV['GIT_USER_NAME']
GIT_USER_EMAIL = ENV['GIT_USER_EMAIL']

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: create-repository-from-list [options]"
  opts.on("-u", "--packages-gh-user GH-REPO-USER") { |v| options[:package_list_user] = v }
  opts.on("-n", "--packages-gh-repo GH-REPO-NAME") { |v| options[:package_list_repository] = v }
end.parse!

abort "Missing ENV GIT_USER_NAME for new commits" if GIT_USER_NAME.nil? || GIT_USER_NAME.empty?
abort "Missing ENV GIT_USER_EMAIL for new commits" if GIT_USER_EMAIL.nil? || GIT_USER_EMAIL.empty?
abort "Missing ENV GITHUB_USER for pushing and creating pull request" if GITHUB_USER.nil? || GITHUB_USER.empty?
abort "Missing ENV GITHUB_TOKEN for pushing and creating pull request" if GITHUB_TOKEN.nil? || GITHUB_TOKEN.empty?

abort "Missing repository user where is package list stored, use -u to spefify" unless options[:package_list_user]
abort "Missing repository name where is package list stored, use -n to spefify" unless options[:package_list_repository]

$logger.info("Fetching current package list")
git_repo = clone_github_repo(options[:package_list_user], options[:package_list_repository], "master", "cloned-current-package-list")
all_packages_content = Hash.new

Dir.glob("cloned-current-package-list/packages-*.yml").each { |package_file_path| 
  kodi_version = File.basename(package_file_path).match(/packages-(?<kodi-version>.+).yml/)["kodi-version"].downcase
  $logger.info("Loading package list for #{kodi_version}")
  all_packages_content[kodi_version] = load_package_list(package_file_path)
}

$logger.info("Search last commit message")
last_commit = get_last_commit_message(git_repo)
$logger.info("Destroying packages list repository")
destroy_git_repo(git_repo)

$logger.info("Fetching current package repository")
cloned_packages_path = "cloned-current-package-repository"
git_repo = clone_github_repo(options[:package_list_user], options[:package_list_repository], "gh-pages", cloned_packages_path)

all_packages_content.each { |kodi_version, packages_content| 

  xmldoc = REXML::Document.new
  xmldoc << REXML::XMLDecl.new("1.0", "UTF-8", "yes")
  xmldoc_addons = xmldoc.add_element("addons")

  packages_content.each_pair { |pkg_id, pkg_info|

    $logger.info("Processing package #{pkg_info[:addon_id]} @ #{kodi_version}")
    package_home_dir = "#{cloned_packages_path}/#{kodi_version}/packages/#{pkg_info[:addon_id]}"
    package_dest_path = "#{package_home_dir}/#{pkg_info[:package_file]}"

    if pkg_info[:type] == "gh-repository"
      package_hash_match = (File.exists?(package_dest_path) && pkg_info[:sha256] == get_sha256_from_zip(package_dest_path))
    else
      package_hash_match = (File.exists?(package_dest_path) && pkg_info[:sha256] == sha256_file(package_dest_path))
    end

    if package_hash_match
      $logger.info("Package #{pkg_info[:addon_id]} @ #{kodi_version} already fetched")
    else
      $logger.info("Fetching package #{pkg_info[:addon_id]} @ #{kodi_version}")
      FileUtils.mkdir_p(package_home_dir) unless File.directory?(package_home_dir)
      fetch_package(pkg_info, package_dest_path, pkg_info[:addon_id])
    end

    # add addon xml into addons
    addon_xml = get_file_content_from_zip(package_dest_path, "addon.xml").force_encoding("utf-8")
    addon_element = get_addon_xml_element(addon_xml)
    xmldoc_addons.add_element(addon_element)

    # iages handle
    [ "icon.png", "fanart.jpg" ].each { |image_path|
      File.delete("#{package_home_dir}/#{image_path}") if File.exists?("#{package_home_dir}/#{image_path}")
    }
    [["icon.png", "icon.png"], ["icon.png","resources/icon.png"], ["fanart.jpg","fanart.jpg"], ["fanart.jpg","resources/fanart.jpg"]].each { |image_path|
      file_content = get_file_content_from_zip(package_dest_path, image_path.last)
      if file_content
        File.open("#{package_home_dir}/#{image_path.first}","wb") { |f| f.write(file_content) }
        next
      end
    }
  }

  $logger.info("Saving #{kodi_version}/addons.xml")
  formatter = REXML::Formatters::Pretty.new(3)
  formatter.compact = true
  output = File.new("#{cloned_packages_path}/#{kodi_version}/addons.xml","w")
  formatter.write(xmldoc, output)
  output.close

  $logger.info("Saving #{kodi_version}/addons.xml.md5")
  File.open("#{cloned_packages_path}/#{kodi_version}/addons.xml.md5","w") { |f| f.write(md5_file("#{cloned_packages_path}/#{kodi_version}/addons.xml")) }
}

if all_packages_content.inject(0) { |total, (kodi_version, packages)| total += packages.count } == 0
  $logger.info("No packages for repository")
elsif repo_has_been_changed?(git_repo)
  $logger.info("Repository has been changed, committing")
  branch_name = "repository-update-#{Time.now.to_i}"
  if last_commit
    commit_message_long = "Repository update triggered by #{last_commit[:message]}\n#{last_commit[:commit].sha}"
    commit_message = "Repository update triggered by #{last_commit[:message]}"
  else
    commit_message_long = "Repository update"
    commit_message = "Repository update"
  end
  commit_changes(git_repo,  commit_message_long)
  $logger.info("Pushing to branch #{branch_name}")
  git_push(git_repo, "gh-pages:#{branch_name}")
  $logger.info("Creating pull request on GitHub")
  create_github_pull_request(
      options[:package_list_user],
      options[:package_list_repository],
      commit_message,
      commit_message_long,
      branch_name,
      "gh-pages"
  )
else
  $logger.info("No changes in packages, nothing to do..")
end
$logger.info("Destroying package repository")
destroy_git_repo(git_repo)
