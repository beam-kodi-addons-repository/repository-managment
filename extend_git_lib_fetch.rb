module Git
  class Lib
    def fetch(remote, opts)
      arr_opts = []
      arr_opts << '--depth' << opts[:depth].to_i if opts[:depth] && opts[:depth].to_i > 0
      arr_opts << remote
      arr_opts << opts[:ref] if opts[:ref]
      arr_opts << '--tags' if opts[:t] || opts[:tags]
      arr_opts << '--prune' if opts[:p] || opts[:prune]
      arr_opts << '--unshallow' if opts[:unshallow]
      command('fetch', arr_opts)
    end
  end
end
