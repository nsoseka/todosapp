require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  enable :reloader
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].select {|todo| todo[:completed] == false}.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def todo_completed?(todo)
    todo[:completed]
  end

  def todo_list_class(todo)
    "complete" if todo_completed?(todo)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition {|list| list_complete?(list)}
    
    incomplete_lists.each {|list| yield(list, lists.index(list))}
    complete_lists.each {|list| yield(list, lists.index(list))}
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition {|todo| todo_completed?(todo)}
    
    incomplete_todos.each {|todo| yield(todo, todos.index(todo))}
    complete_todos.each {|todo| yield(todo, todos.index(todo))}
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect '/lists'
end

# view all the list
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# render the new list form
get "/lists/new" do

  erb :new_list, layout: :layout
end

# Return an error message if name is invalid, return nil otherwise
def error_for_list_name(name)
  if session[:lists].any? { |list| list[:name] == name }
    "The list names must be unique"
  elsif !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters"
  end
end

# Return an error message if name is invalid, return nil otherwise
def error_for_todo_name(name)
  if !(1..100).cover? name.size
    "todo must be between 1 and 100 characters"
  end
end

# create the new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created"
    redirect "/lists"
  end
end

# view todo in a list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# Edit existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# update existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated"
    redirect "/lists/#{id}"
  end
end

# delete a todo list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted"
  redirect "/lists"
end

# adding a new todo item
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo_name(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from the list
post "/lists/:id/todos/:index/delete" do
  todo_id = params[:index].to_i
  @list_id = params[:id].to_i
  list = session[:lists][@list_id]

  list[:todos].delete_at(todo_id)
  session[:success] = "the todo has been deleted"
  redirect "lists/#{@list_id}"
end

# Marking a todo item as completed
post '/lists/:list_id/todos/:todo_id/completed' do
  todo_id = params[:todo_id].to_i
  @list_id = params[:list_id].to_i
  @todo = session[:lists][@list_id][:todos][todo_id]

  if @todo[:completed] == false
    @todo[:completed] = true
  else
    @todo[:completed] = false
  end
  session[:success] = "todo has been updated"
  redirect "/lists/#{@list_id}"
end

# mark all todo items as complete
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @todos = session[:lists][@list_id][:todos]

  if @todos.select {|todo| todo[:completed] == false}.size > 0
    @todos.each {|todo| todo[:completed] = true}
  else
    @todos.each {|todo| todo[:completed] = false}
  end
  session[:success] = "All todos have been completed"
  redirect "/lists/#{@list_id}"
end
