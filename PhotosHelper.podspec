Pod::Spec.new do |s|
  s.name             = "PhotosHelper"
  s.version          = "0.2.1"
  s.summary          = "Collection of methods to work with Photos Framework in Swift."

  s.description      = <<-DESC
                       Simplest way to interact with the Photos.app.
                       Create albums, save images in one line of code.
                       Asynchronous, closure based, written in latest Swift.

                       Constantly updated, support for other asset types will come soon.
                       DESC

  s.homepage         = "https://github.com/DroidsOnRoids/PhotosHelper"
  s.license          = 'MIT'
  s.author           = { "Andrzej Filipowicz" => "afilipowicz.4@gmail.com" }
  s.source           = { :git => "https://github.com/DroidsOnRoids/PhotosHelper.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/NJFilipowicz'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'PhotosHelper.swift'

  s.frameworks = 'Photos'
end
