# frozen_string_literal: true

require 'gobject-introspection'

module Notify
end

notify_loader = GObjectIntrospection::Loader.new(Notify)
notify_loader.load('Notify')

Notify.init(Environment::NAME)

Plugin.create(:libnotify_gi) do
 on_popup_notify do |user, text, &stop|
    icon_path(user.icon).trap do |err|
      warn err
      icon_path(Skin[:notfound])
    end.next do |icon_file_name|
      # TODO: アイコンを一時ファイルに書き込まず、Notification#set_image_from_pixbuf(Gdk::Pixbuf)を使えるかもしれない
      # https://valadoc.org/libnotify/Notify.Notification.set_image_from_pixbuf.html
      notify = if text.is_a? Diva::Model
                 notify.set_category('system')
                 Notify::Notification.new(user.title, text.description.to_s, icon_file_name)
               else
                 Notify::Notification.new(user.title, text.to_s, icon_file_name)
               end
      notify.set_timeout(UserConfig[:notify_expire_time].to_i * 1000)
      notify.set_hint('desktop-entry', Environment::NAME)
      notify.show
    end.trap do |err|
      error err
      notice "user=#{user.inspect}, text=#{text.inspect}"
    end
    stop.call
  end

  def icon_path(photo)
    fn = File.join(icon_tmp_dir, Digest::MD5.hexdigest(photo.uri.to_s) + '.png')
    Delayer::Deferred.new.next do
      case
      when FileTest.exist?(fn)
        fn
      else
        photo.download_pixbuf(width: 48, height: 48).next do |p|
          FileUtils.mkdir_p(icon_tmp_dir)
          photo.pixbuf(width: 48, height: 48).save(fn, 'png')
          fn
        end
      end
    end
  end

  memoize def icon_tmp_dir
    File.join(Environment::TMPDIR, 'libnotify', 'icon').freeze
  end
end
