require 'dotenv/load'
require 'rexml/document'
require 'open-uri'
require 'fileutils'
require 'digest'
require 'zip'
require 'github_api'
require 'fileutils'
require 'git'
require 'yaml'
require 'logger'

$logger = Logger.new(STDOUT)

require_relative 'extend_git_lib_fetch'

def create_github_pull_request(repository_user, repository_name, title, body, head_branch, base_branch)
  github = Github.new(oauth_token: GITHUB_TOKEN)
  github.pull_requests.create repository_user, repository_name,
    title: title,
    body: body,
    head: head_branch,
    base: base_branch
end

def open_git_repo(path)
  return Git.open(path)
end

def clone_github_repo(repository_user, repository_name, branch, path = nil)
  path = repository_name if path.nil?
  git_repo = Git.clone("https://#{GITHUB_USER}:#{GITHUB_TOKEN}@github.com/#{repository_user}/#{repository_name}.git", path, { depth: 1, branch: branch} )
  git_repo.config('user.name', GIT_USER_NAME)
  git_repo.config('user.email', GIT_USER_EMAIL)
  return git_repo
end

def clone_github_repo_at_sha(repository, sha, path, depth = 1)
  git_repo = Git.init(path)
  git_repo.add_remote("origin", "https://#{GITHUB_USER}:#{GITHUB_TOKEN}@github.com/#{repository}.git")
  git_repo.fetch("origin", depth: 1, ref: sha)
  git_repo.checkout("FETCH_HEAD")
  return git_repo
end

def load_package_list(package_list_file)
  packages_content = YAML.load(File.read(package_list_file))
  packages_content = Hash.new unless packages_content.is_a?(Hash)
  return packages_content
end

def update_package_list(packages_content, update_options)
  packages_content[update_options[:addon_id]] = update_options
  return packages_content.sort.to_h
end

def checkout_branch(git_repo, branch)
  git_repo.branch(branch).checkout
end

def write_package_list(package_list_file, content)
  File.open(package_list_file, "w") { |f| f.write(content.to_yaml) }
end

def commit_changes(git_repo, message)
  git_repo.add(:all => true)
  git_repo.commit(message)
end

def destroy_git_repo(git_repo)
  FileUtils.rm_rf(git_repo.dir.path)
end

def download_file(url, path)
  case io = open(url)
  when StringIO then File.open(path, 'w') { |f| f.write(io) }
  when Tempfile then io.close; FileUtils.mv(io.path, path)
  end
end

def sha256_file(path)
  sha256 = Digest::SHA256.file path
  sha256.hexdigest
end

def get_addon_info_from_xml(xml_content)
  result = {}
  xmldoc = REXML::Document.new(xml_content)

  result[:addon_id] = xmldoc.elements["addon"].attribute(:id).value
  result[:addon_version] = xmldoc.elements["addon"].attribute(:version).value
  result[:package_file] = "#{result[:addon_id]}-#{result[:addon_version]}.zip"
  return result
end

def fetch_release_file_from_github(params, path)
  fetch_url = "https://github.com/#{params[:github_repository]}/releases/download/#{params[:github_release]}/#{params[:github_filename]}"
  download_file(fetch_url, path)
end

def get_file_content_from_zip(path, path_in_zip)
  Zip::File.open(path) do |zip_file|
    zip_file.each do |entry|
      if entry.file? && entry.name == path_in_zip
        return entry.get_input_stream.read
      end
    end
  end
  return nil
end

def get_file_content_from_git(git_repo, tag, path)
  git_repo.show(tag, path)
end

def git_archive(git_repo, tag, file)
  git_repo.archive(tag, file)
end