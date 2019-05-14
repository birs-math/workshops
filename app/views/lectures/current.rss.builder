xml.rss :version => "2.0" do
  xml.title "Current Lecture"
  xml.description "Best guess at current lecture in #{@room}."
  xml.link @schedule_url

  xml.item do
    xml.title @lecture.title
    xml.speaker @lecture.person.name
    xml.affiliation @lecture.person.affiliation
    xml.start_time @lecture.start_time
    xml.end_time @lecture.end_time
    xml.description @lecture.abstract
  end
end