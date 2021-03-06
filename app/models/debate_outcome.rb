class DebateOutcome < ActiveRecord::Base
  # By default we want the user to upload a '2x' style image, and we can then
  # resize it down with Imagemagick
  COMMONS_IMAGE_SIZE = { w: 1260.0, h: 710.0 }

  VALID_OTHER_URLS = /\Ahttps?:\/\/(?:[a-z][\-\.a-z0-9]{0,63}\.parliament\.uk|www\.youtube\.com).*\z/
  VALID_VIDEO_URLS = /\Ahttps?:\/\/(?:(?:www\.)?parliamentlive\.tv|www\.youtube\.com).*\z/

  belongs_to :petition, touch: true

  validates :petition, presence: true
  validates :debated_on, presence: true, if: :debated?
  validates :transcript_url, :video_url, :debate_pack_url, length: { maximum: 500 }

  validates :debate_pack_url, format: { with: VALID_OTHER_URLS }, allow_blank: true
  validates :transcript_url, format: { with: VALID_OTHER_URLS }, allow_blank: true
  validates :video_url, format: { with: VALID_VIDEO_URLS }, allow_blank: true

  has_attached_file :commons_image,
    # default_url needs to be a lambda - this way the generated image url will
    # include any asset-digest
    default_url: ->(_) { ActionController::Base.helpers.image_url("graphics/graphic_house-of-commons.jpg") },
    styles: {
      "1x": "#{(COMMONS_IMAGE_SIZE[:w]/2).to_i}x#{(COMMONS_IMAGE_SIZE[:h]/2).to_i}",
      "2x": "#{COMMONS_IMAGE_SIZE[:w]}x#{COMMONS_IMAGE_SIZE[:h]}"
    }

  validates_attachment_content_type :commons_image, content_type: /\Aimage\/.*\Z/
  validate :validate_commons_image_dimensions, unless: :no_commons_image_queued

  after_create do
    Appsignal.increment_counter("petition.debated", 1)
    petition.touch(:debate_outcome_at) unless petition.debate_outcome_at?
  end

  after_save do
    petition.update_columns(debate_state: debate_state)
  end

  def date
    debated_on
  end

  private

  def debate_state
    debated? ? 'debated' : 'not_debated'
  end

  def image_ratio(width, height)
    (width.to_f / height.to_f).round(2)
  end

  def no_commons_image_queued
    commons_image.blank? || !commons_image.queued_for_write[:original]
  end

  def validate_commons_image_dimensions
    # This should be tuned if the images start looking badly scaled
    max_ratio_delta = 0.1

    dimensions = Paperclip::Geometry.from_file(commons_image.queued_for_write[:original].path)

    if dimensions.width < COMMONS_IMAGE_SIZE[:w]
      errors.add(:commons_image, :too_narrow, width: dimensions.width, min_width: COMMONS_IMAGE_SIZE[:w])
    end

    if dimensions.height < COMMONS_IMAGE_SIZE[:h]
      errors.add(:commons_image, :too_short, height: dimensions.height, min_height: COMMONS_IMAGE_SIZE[:h])
    end

    expected_ratio = image_ratio(COMMONS_IMAGE_SIZE[:w], COMMONS_IMAGE_SIZE[:h])
    actual_ratio = image_ratio(dimensions.width, dimensions.height)

    min_ratio = (expected_ratio - max_ratio_delta).round(2)
    max_ratio = (expected_ratio + max_ratio_delta).round(2)
    unless (min_ratio..max_ratio).include? actual_ratio
      errors.add(:commons_image, :incorrect_ratio, ratio: actual_ratio, min_ratio: min_ratio, max_ratio: max_ratio)
    end
  end
end
