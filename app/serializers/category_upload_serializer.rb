class CategoryUploadSerializer < ApplicationSerializer
  attributes :id, :url, :aspect_ratio
  
  def aspect_ratio
    "--aspect-ratio:#{object.width}/#{object.height}"
  end
end
