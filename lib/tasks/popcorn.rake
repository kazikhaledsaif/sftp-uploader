# Demo data so every screen has something to show.
#   docker compose exec web bin/rails popcorn:demo        # add (safe to run again)
#   docker compose exec web bin/rails popcorn:demo:clear  # remove demo data only
#
# Demo titles carry details["demo"] = true; nothing else is touched.
# Scores and runtimes are approximate; with TMDB_API_KEY set, opening a title
# replaces them with real data and artwork.
namespace :popcorn do
  MOVIES = [
    # name, year, lang, minutes, genres, approx score, overview
    ["Dangal", 2016, "hi", 161, "Drama, Sport", 8.0, "A former wrestler trains his two daughters to become world-class wrestlers."],
    ["3 Idiots", 2009, "hi", 170, "Comedy, Drama", 8.0, "Two friends search for a long-lost college companion who taught them to think differently."],
    ["Inception", 2010, "en", 148, "Science Fiction, Action", 8.4, "A thief who steals secrets from dreams is given one last job: plant an idea."],
    ["Interstellar", 2014, "en", 169, "Science Fiction, Drama", 8.4, "Explorers travel through a wormhole to find humanity a new home."],
    ["Zindagi Na Milegi Dobara", 2011, "hi", 155, "Comedy, Drama", 7.7, "Three friends take a road trip across Spain before one of them gets married."],
    ["Andhadhun", 2018, "hi", 139, "Thriller, Crime", 7.9, "A pianist pretending to be blind witnesses a murder."],
    ["Parasite", 2019, "ko", 132, "Thriller, Drama", 8.5, "A poor family schemes its way into working for a wealthy household."],
    ["The Dark Knight", 2008, "en", 152, "Action, Crime", 8.5, "Batman faces the Joker, who wants to plunge Gotham into chaos."],
    ["Oppenheimer", 2023, "en", 180, "Drama, History", 8.1, "The story of the physicist behind the first atomic bomb."],
    ["Lagaan", 2001, "hi", 224, "Drama, Sport", 7.8, "Villagers stake everything on a cricket match against their colonial rulers."],
    ["Queen", 2013, "hi", 146, "Comedy, Drama", 7.4, "Jilted before her wedding, a young woman goes on her honeymoon alone."],
    ["Everything Everywhere All at Once", 2022, "en", 139, "Science Fiction, Comedy", 7.8, "A laundromat owner discovers she can connect with versions of herself in other universes."],
    ["Whiplash", 2014, "en", 107, "Drama, Music", 8.4, "A young drummer is pushed to the edge by a ruthless music teacher."],
    ["Taare Zameen Par", 2007, "hi", 165, "Drama, Family", 8.0, "An art teacher helps a boy struggling with dyslexia."],
    ["Barfi!", 2012, "hi", 151, "Comedy, Romance", 7.6, "A charming deaf and mute man and the two women who love him."]
  ].freeze

  WANT = [
    ["Dune: Part Two", 2024, "en", 166, "Science Fiction, Adventure", 8.1, "Paul Atreides unites with the Fremen to take revenge."],
    ["Laapataa Ladies", 2024, "hi", 122, "Comedy, Drama", 8.0, "Two brides get swapped on a train, setting off a search across villages."],
    ["12th Fail", 2023, "hi", 147, "Drama", 8.3, "A young man from a poor village fights to clear the civil services exam."],
    ["Past Lives", 2023, "en", 106, "Drama, Romance", 7.7, "Two childhood friends reunite in New York after twenty years."],
    ["The Lunchbox", 2013, "hi", 104, "Drama, Romance", 7.3, "A mistaken lunchbox delivery connects a lonely widower and a housewife."],
    ["Spirited Away", 2001, "ja", 125, "Animation, Fantasy", 8.5, "A girl must work in a spirit bathhouse to free her parents."],
    ["Gangs of Wasseypur", 2012, "hi", 321, "Crime, Drama", 8.0, "A decades-long blood feud between coal-mafia families."]
  ].freeze

  SHOWS = [
    # name, year, lang, minutes/episode, genres, score, seasons(episodes), watched seasons, overview
    ["Panchayat", 2020, "hi", 35, "Comedy, Drama", 8.9, [8, 8, 8, 8], [1, 2, 3], "An engineering graduate takes a job as secretary of a remote village council."],
    ["Sacred Games", 2018, "hi", 50, "Crime, Thriller", 8.5, [8, 8], [1, 2], "A Mumbai cop gets a call from a gangster warning him to save the city."],
    ["Breaking Bad", 2008, "en", 47, "Crime, Drama", 8.9, [7, 13, 13, 13, 16], [1, 2], "A chemistry teacher turns to making drugs after a cancer diagnosis."],
    ["Stranger Things", 2016, "en", 51, "Drama, Mystery", 8.6, [8, 9, 8, 9], [], "Kids in a small town uncover secret experiments and a hidden world."],
    ["Kota Factory", 2019, "hi", 40, "Drama, Comedy", 9.0, [5, 5, 5], [], "Students in India's coaching hub prepare for engineering entrance exams."],
    ["The Family Man", 2019, "hi", 45, "Action, Thriller", 8.4, [10, 9], [1], "A middle-class man secretly works for a special national security unit."]
  ].freeze

  desc "Add demo titles, diary entries and plans"
  task demo: :environment do
    today = Date.current
    rand = Random.new(42) # same "random" history every run
    make = lambda do |name, year, lang, minutes, genres, score, overview, media|
      Title.find_or_create_by!(name: name, media_type: media) do |t|
        t.assign_attributes(year: year, original_language: lang, runtime: minutes, genres: genres, tmdb_rating: score,
                            overview: overview, details: { "demo" => true })
      end
    end

    MOVIES.each_with_index do |(name, year, lang, minutes, genres, score, overview), i|
      title = make.(name, year, lang, minutes, genres, score, overview, "movie")
      next if title.viewings.any?

      title.log_watch!(on: today - (6 + i * 23 + rand.rand(10)), rating: [7, 8, 8, 9, 9, 10, 6].sample(random: rand),
                       note: { 0 => "Cried at the final match.", 2 => "Need to watch again for the details.",
                               6 => "That basement scene." }[i])
    end
    # A rewatch, so the diary shows the same movie twice.
    inception = Title.find_by(name: "Inception")
    inception.log_watch!(on: today - 4, rating: 10, note: "Even better the second time.") if inception.viewings.size == 1

    WANT.each { |(name, year, lang, minutes, genres, score, overview)| make.(name, year, lang, minutes, genres, score, overview, "movie") }

    upcoming = Title.find_or_create_by!(name: "Avengers: Doomsday", media_type: "movie") do |t|
      t.assign_attributes(year: 2026, original_language: "en", genres: "Action, Science Fiction",
                          release_date: Date.new(2026, 12, 18), details: { "demo" => true },
                          overview: "The Avengers regroup against a new threat.")
    end
    upcoming.update!(release_date: today + 20) if upcoming.release_date <= today # keep it in the future

    SHOWS.each do |(name, year, lang, minutes, genres, score, episodes, watched, overview)|
      show = make.(name, year, lang, minutes, genres, score, overview, "tv")
      episodes.each_with_index { |count, i| show.seasons.find_or_create_by!(number: i + 1) { |s| s.episode_count = count } }
      next if show.viewings.any?

      watched.each_with_index do |n, i|
        show.log_watch!(season_numbers: [n], on: today - (90 - i * 30 + rand.rand(5)), rating: [8, 9, 9, 10].sample(random: rand))
      end
    end

    # Plans: Friday and Saturday this week, and one from yesterday to show "Did you watch it?".
    friday = today + ((5 - today.wday) % 7)
    saturday = today + ((6 - today.wday) % 7)
    friday += 7 if friday <= today
    saturday += 7 if saturday <= today
    { ["Dune: Part Two", nil] => saturday, ["Panchayat", 4] => friday, ["Laapataa Ladies", nil] => today - 1 }
      .each do |(name, season), date|
        title = Title.find_by!(name: name)
        title.plans.find_or_create_by!(season_number: season) { |p| p.planned_on = date }
      end

    puts "Demo data ready: #{Title.where("json_extract(details, '$.demo') = 1").count} titles, " \
         "#{Viewing.count} diary entries, #{Plan.count} plans."
  end

  namespace :demo do
    desc "Remove the demo titles (and their diary entries and plans)"
    task clear: :environment do
      demo = Title.where("json_extract(details, '$.demo') = 1")
      count = demo.count
      demo.destroy_all
      puts "Removed #{count} demo titles."
    end
  end
end
