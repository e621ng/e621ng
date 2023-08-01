module Moderator
  class IpAddrSearch
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def execute
      with_history = params[:with_history].to_s.truthy?
      if params[:user_id].present?
        search_by_user_id(params[:user_id].split(",").map(&:strip), with_history)
      elsif params[:user_name].present?
        search_by_user_name(params[:user_name].split(",").map(&:strip), with_history)
      elsif params[:ip_addr].present?
        ip_addrs = params[:ip_addr].split(",").map(&:strip)
        if params[:add_ip_mask].to_s.truthy? && ip_addrs.count == 1 && ip_addrs[0].exclude?("/")
          mask = IPAddr.new(ip_addrs[0]).ipv4? ? 24 : 64
          ip_addrs[0] = "#{ip_addrs[0]}/#{mask}"
        end
        search_by_ip_addr(ip_addrs, with_history)
      else
        []
      end
    end

    private

    def search_by_ip_addr(ip_addrs, with_history)
      def add_by_ip_addr(target, name, ips, klass, ip_field, id_field)
        if ips.size == 1
          target.merge!({name => klass.where("#{ip_field} <<= ?", ips[0]).group(id_field).count})
        else
          target.merge!({name => klass.where(ip_field => ips).group(id_field).count})
        end
      end

      sums = {}
      add_by_ip_addr(sums, :comment, ip_addrs, ::Comment, :creator_ip_addr, :creator_id)
      add_by_ip_addr(sums, :dmail, ip_addrs, ::Dmail, :creator_ip_addr, :from_id)
      add_by_ip_addr(sums, :blip, ip_addrs, ::Blip, :creator_ip_addr, :creator_id)
      add_by_ip_addr(sums, :post_flag, ip_addrs, ::PostFlag, :creator_ip_addr, :creator_id)
      add_by_ip_addr(sums, :posts, ip_addrs, ::Post, :uploader_ip_addr, :uploader_id)
      add_by_ip_addr(sums, :last_login, ip_addrs, ::User, :last_ip_addr, :id)

      if with_history
        add_by_ip_addr(sums, :artist_version, ip_addrs, ::ArtistVersion, :updater_ip_addr, :updater_id)
        add_by_ip_addr(sums, :note_version, ip_addrs, ::NoteVersion, :updater_ip_addr, :updater_id)
        add_by_ip_addr(sums, :pool_version, ip_addrs, ::PoolVersion, :updater_ip_addr, :updater_id)
        add_by_ip_addr(sums, :post_version, ip_addrs, ::PostVersion, :updater_ip_addr, :updater_id)
        add_by_ip_addr(sums, :wiki_page_version, ip_addrs, ::WikiPageVersion, :updater_ip_addr, :updater_id)
      end

      user_ids = sums.map { |_, v| v.map { |k, _| k } }.reduce([]) { |ids, id| ids + id }.uniq
      users = ::User.where(id: user_ids).map { |u| [u.id, u] }.to_h
      {sums: sums, users: users}
    end

    def search_by_user_name(user_names, with_history)
      user_ids = user_names.map { |name| ::User.name_to_id(name) }
      search_by_user_id(user_ids, with_history)
    end

    def search_by_user_id(user_ids, with_history)
      def add_by_user_id(target, name, ids, klass, ip_field, id_field)
          target.merge!({name => klass.where(id_field => ids).where.not(ip_field => nil).group(ip_field).count})
      end

      sums = {}
      add_by_user_id(sums, :comment, user_ids, ::Comment, :creator_ip_addr, :creator_id)
      add_by_user_id(sums, :dmail, user_ids, ::Dmail, :creator_ip_addr, :from_id)
      add_by_user_id(sums, :blip, user_ids, ::Blip, :creator_ip_addr, :creator_id)
      add_by_user_id(sums, :post_flag, user_ids, ::PostFlag, :creator_ip_addr, :creator_id)
      add_by_user_id(sums, :posts, user_ids, ::Post, :uploader_ip_addr, :uploader_id)
      add_by_user_id(sums, :users, user_ids, ::User, :last_ip_addr, :id)

      if with_history
        add_by_user_id(sums, :artist_version, user_ids, ::ArtistVersion, :updater_ip_addr, :updater_id)
        add_by_user_id(sums, :note_version, user_ids, ::NoteVersion, :updater_ip_addr, :updater_id)
        add_by_user_id(sums, :pool_version, user_ids, ::PoolVersion, :updater_ip_addr, :updater_id)
        add_by_user_id(sums, :post_version, user_ids, ::PostVersion, :updater_ip_addr, :updater_id)
        add_by_user_id(sums, :wiki_page_version, user_ids, ::WikiPageVersion, :updater_ip_addr, :updater_id)
      end

      ip_addrs = sums.map { |_, v| v.map { |k, _| k } }.reduce([]) { |ids, id| ids + id }.uniq
      {sums: sums, ip_addrs: ip_addrs}
    end
  end
end
