namespace :locations do
  desc "Report legacy event location values that do not yet have canonical locations"
  task backfill_report: :environment do
    puts "Training sessions without location_id:"
    TrainingSession.where(location_id: nil).where.not(location: [ nil, "" ]).group(:location).count.sort.each do |name, count|
      puts "  #{name}: #{count}"
    end

    puts "Tournaments without location_id:"
    rows = Tournament.where(location_id: nil)
                     .where.not(location_name: [ nil, "" ])
                     .group(:location_name, :city, :state, :country)
                     .count
    rows.sort_by { |values, _count| values.compact.join(" ") }.each do |values, count|
      puts "  #{values.compact.join(', ')}: #{count}"
    end
  end
end