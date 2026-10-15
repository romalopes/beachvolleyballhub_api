# Service-level rule failures carry their own message, but Rails' RecordInvalid
# accepts only the record — a second argument raises ArgumentError. Record the
# message on :base first so both `exception.message` and
# `record.errors.full_messages` surface it (the controller renders the latter).
module InvalidRecord
  def raise_invalid!(record, message)
    record.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, record
  end
end
