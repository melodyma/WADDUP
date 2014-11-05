#eb = Eventbrite
#nyt = New York Times
helpers do
  
  def category_match_hash  #For normalizing categories
    {
      1 => { #Music
        :eb => 103,
        :nyt => "Jazz+Pop+Classical"
      },
      2 => { #Charity & Causes
        :eb => 111
      },
      3 => { #Food & Drink
        :eb => 110
      },
      4 => { #Performing & Visual Arts
        :eb => 105,
        :nyt => "Theatre+Dance+Comedy"
      },
      5 => { #Film, Media & Entertainment
        :eb => 104,
        :nyt => "Movies"
      },
      6 => { #Sports & Fitness
        :eb => 108
      },
      7 => { #"Hobbies & Special Interest"
        :eb => 119,
        :nyt => "spareTimes"
      },
      8 => { #Family & Education
        :eb => 115,
        :nyt => "forChildren"
      }
    }
  end

  #For getting Eventbrite's category code
  def convert_to_categories(category_num, source)
    category_match_hash[category_num][source]
  end

  #Getting JSON from API calls
  def fetch(uri)
    resp = Net::HTTP.get_response(URI.parse(URI.encode(uri.to_s)))
      if resp.code == "301"
        resp = Net::HTTP.get_response(URI.parse(resp.header['location']))
      end
    data = resp.body
    JSON.parse(data)
  end

  #Getting [latitude,longitude] from user's address input using Geocoder
  def get_lat_lng_from_address(address)
    if address
      ll = Geocoder.coordinates(address)
      @latitude = ll[0]
      @longitude = ll[1]
    end
  end

  #Normalizing date and time for interface
  def date_time_conversion(date_time)
    if date_time
      DateTime.parse(date_time).strftime('%a, %b. %d at %l %P')
    end
  end

  def uri_build(host, path, search_string)
    URI::HTTP.build({ :host => host, :path => path, :query => search_string })
  end

  #Grabbing images from Google for events using ImageSuckr gem
  def image_grab(event_title, city, category)
    suckr = ImageSuckr::GoogleSuckr.new
    query = event_title + " " + category #Appending city name to increase positive image result
    grabbed_image = suckr.get_image_url({"q" => query.to_s, "imgsz" => "medium", "rsz" => "1"})
  end

end

get '/' do
  erb :'/index'
end

get '/search' do
  get_lat_lng_from_address(params[:address])
  range_in_km = params[:range_in_km]
  start_date = params[:start_date]
  end_date = params[:end_date]
  @eb_categories = convert_to_categories(params[:categories].to_i, :eb)
  @nyt_categories = convert_to_categories(params[:categories].to_i, :nyt)
  eb_api_key = 'RMSW4TDEECLT2OCKQT4U'
  nyt_api_key = '9918a316ad258146bc448156aa83bfb4:10:69860552' 
  
  #Outputting events
  @events = []

  #Building URIs for API calls  
  @eb_search_string = "token=#{eb_api_key}&location.latitude=#{@latitude}&location.longitude=#{@longitude}&location.within=#{range_in_km}km&categories=#{@eb_categories}&start_date.range_start=#{start_date}T00:00:00Z&start_date.range_end=#{end_date}T23:59:59Z"
  @nyt_search_string = "api-key=#{nyt_api_key}&ll=#{@latitude},#{@longitude}&radius=#{(range_in_km.to_i * 1000).to_s}&filters=category:(#{@nyt_categories})&date_range=#{start_date}:#{end_date}"

  def eb_events
    @fetched_events = fetch(uri_build('www.eventbriteapi.com', '/v3/events/search/', @eb_search_string))
    @fetched_events["events"].each do |event|
      event = {
        :picture => event["logo_url"] ||= image_grab(event["name"]["text"], event["venue"]["location"], event["category"]["name"]),
        :title => event["name"]["text"],
        :description => event["description"]["text"],
        :event_uri => event["url"],
        :venue_address_1 => event["venue"]["address"]["address_1"],
        :venue_city => event["venue"]["address"]["city"],
        :category => event["category"]["name"],
        :start_date_time => date_time_conversion(event["start"]["local"]),
        :end_date_time => date_time_conversion(event["end"]["local"]),
        :origin => "Eventbrite"
      }
      @events << event
    end 
  end

  def nyt_events
    @fetched_events = fetch(uri_build('api.nytimes.com', '/svc/events/v2/listings', @nyt_search_string))
    @fetched_events["results"].each do |event|
      event = {
        :picture => image_grab(event["event_name"], event["city"], event["category"]),
        :title => event["event_name"],
        :description => event["web_description"],
        :event_uri => event["event_detail_url"],
        :venue_address_1 => event["street_address"], 
        :venue_city => event["city"],
        :category => event["category"],
        :start_date_time => event["date_time_description"],
        :end_date_time => date_time_conversion(event["recurring_end_date"]),
        :free => event["free"],
        :origin => "New York Times"
      }
      @events << event
    end 
  end

  if @nyt_categories 
    nyt_events
  end
  eb_events
  @events.shuffle!
  erb :'/index'

end