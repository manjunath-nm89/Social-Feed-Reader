require "sinatra"
require 'koala'
require "date"
if development?
  require "sinatra/reloader" 
  require 'debugger' 
end

enable :sessions
set :raise_errors, false
set :show_exceptions, false

# Scope defines what permissions that we are asking the user to grant.
# In this example, we are asking for the ability to publish stories
# about using the app, access to what the user likes, and to be able
# to use their pictures.  You should rewrite this scope with whatever
# permissions your app needs.
# See https://developers.facebook.com/docs/reference/api/permissions/
# for a full list of permissions
FACEBOOK_SCOPE = ''
STORY_LENGTH = 200

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
end

helpers do
  def host
    request.env['HTTP_HOST']
  end

  def scheme
    request.scheme
  end

  def url_no_scheme(path = '')
    "//#{host}#{path}"
  end

  def url(path = '')
    "#{scheme}://#{host}#{path}"
  end

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end
  
  def result_parser(search_result_array)
    output_array = []
    (search_result_array || []).each do |result_hash|
      from_details = result_hash["from"]
      output_array << %Q{
        <div class="content_wrapper">
          <div class="fb_img pull-left"> 
            <a href="https://www.facebook.com/#{from_details["id"]}" target="_blank">
              <img src="https://graph.facebook.com/#{from_details["id"]}/picture?type=square" alt="#{from_details["name"]}"/>
            </a>  
          </div>
          <div class="content">
            <div class="content_name bold-font">
              <a href="https://www.facebook.com/#{from_details["id"]}" target="_blank">
                #{from_details["name"]}
              </a>  
            </div>
            <div class="content_message">
              #{get_content(result_hash)}
            </div>
            <div class="footer-options mini-font">
              <abbr class="timeago" title="#{result_hash["created_time"]}">#{DateTime.parse(result_hash["created_time"]).to_time.strftime("%d %b, %Y")}</abbr>
              <span class="separator"></span>
              <a href="#">share</a>
            </div>
          </div>
        </div>  
      } 
    end
    output_array.join("")
  end

  def fb_truncate(string, length, link, link_title = "Read full story")
    if string.size > length
      content = %Q{
        "#{string[0..STORY_LENGTH]}.."
        <a href='#{link}' target='_blank' class="mini-font">#{link_title}</a>
      }
    else
      content = string    
    end
    return content
  end

  def get_content(result_hash)
    if result_hash["message"].nil?
      content = %Q{
        <div>
          #{result_hash["story"]}
        </div>  
      }  
      content += fb_truncate(result_hash["caption"].to_s, STORY_LENGTH, "http://www.facebook.com/#{result_hash["id"]}")
      if result_hash["type"] == "video"
        content += %Q{
          <div class="iframe_container mini-font">
            <a href="#{result_hash["link"]}">#{result_hash["link"]}</a>
          </div>  
        }
      elsif result_hash["type"] == "link"
        content += %Q{
          <a href="#{result_hash["link"]}" target="_blank">#{result_hash["link"]}</a>
        }  
      else
        content += %Q{
          <a href="#{result_hash["link"]}" target="_blank"><br/>
            <img class="caption-image" src="https://graph.facebook.com/#{result_hash["object_id"]}/picture"/>
          </a>  
        }
      end
      return content
    else
      return fb_truncate(result_hash["message"], STORY_LENGTH, "http://www.facebook.com/#{result_hash["id"]}")
    end
  end
end

# the facebook session expired! reset ours and restart the process
error(Koala::Facebook::APIError) do
  session[:access_token] = nil
  redirect "/auth/facebook"
end

get "/" do
  intialize_graph_user
  erb :index
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/" do
  redirect "/"
end

# used to close the browser window opened to post to wall/send to friends
get "/close" do
  "<body onload='window.close();'/>"
end

get "/sign_out" do
  session[:access_token] = nil
  redirect '/'
end

get "/auth/facebook" do
  session[:access_token] = nil
  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
end

get '/auth/facebook/callback' do
	session[:access_token] = authenticator.get_access_token(params[:code])
	redirect '/'
end

get "/search" do
  intialize_graph_user
  if !params.delete("pagination").to_s.empty?
    @search_results = @graph.get_page(["search", params])
  else
    query = params[:query]
    @search_results = @graph.search(query)
  end
  erb :search_results, :layout  => false
end 

def intialize_graph_user
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(session[:access_token])

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
  if session[:access_token]
    @user = @graph.get_object("me")
  end
end
