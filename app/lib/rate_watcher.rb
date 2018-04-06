class RateWatcher
  def get_rate
    Message.where('succeeded_at > ?', DateTime.now - 1.minute).count
  end
end
