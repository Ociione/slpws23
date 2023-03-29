require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'jwt'
require_relative 'model.rb'

enable :sessions

def verify_token(token)
    begin
        decoded_token = JWT.decode token, 'ojojoj!', true, { algorithm: 'HS256' }
        return true, decoded_token
    rescue JWT::DecodeError
        return false, nil
    end
end

get('/') do
    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    db = SQLite3::Database.new('db/database.db')
    db.results_as_hash = true

    skrin = db.execute("SELECT * FROM cases")
    balance = db.execute("SELECT balance FROM user WHERE id = ?", decoded_token[0]['sub'])
    email = db.execute("SELECT email FROM user WHERE id = ?", decoded_token[0]['sub'])
    items = db.execute("SELECT * FROM u_item WHERE user_id = ?", decoded_token[0]['sub'])
    name = db.execute("SELECT item.name FROM u_item LEFT JOIN item ON u_item.item_id = item.id")
    
    db.close

    j = 0

    slim(:index, locals:{skrin:skrin, balance:balance, email:email, items:items, name:name, j:j})
end

get('/register') do
    error = params['error']
    if error == "1"
        error = 'Felaktig input'
    elsif error == "2"
        error = 'Användare finns redan'
    end

    slim(:register, locals:{error:error})
end

get('/login') do
    error = params['error']
    if error == "1"
        error = 'Användare finns inte eller så angavs fel lösenord'
    end

    slim(:login, locals:{error:error})
end

post('/register') do
    email = params['email']
    password = params['password']
    password2 = params['password2']
    if password != password2 or password.length < 2 or email.length < 2 or !email.include?('@')
        redirect('/register?error=1')
    end

    db = SQLite3::Database.new('db/database.db')
    db.results_as_hash = true
    password = BCrypt::Password.create(params['password'])
    starting_balance = 10.0

    begin
        db.execute("INSERT INTO user (email, password, balance) VALUES (?, ?, ?)", email, password, starting_balance)
    rescue
        redirect('/register?error=2')
    end

    db.close

    redirect('/login')
end

post('/login') do
    email = params['email']
    password = params['password']

    if password.length < 2 or email.length < 2 or !email.include?('@')
        redirect('/login?error=1')
    end

    db = SQLite3::Database.new('db/database.db')
    db.results_as_hash = true

    result = db.execute("SELECT * FROM user WHERE email = ?", email)
    db.close

    if result.empty?
        redirect('/login?error=1')
    end

    if BCrypt::Password.new(result[0]['password']) == password
        payload = { sub: result[0]['id'] }
        token = JWT.encode payload, 'ojojoj!', 'HS256'

        session[:token] = token

        redirect('/')
    end

    redirect('/login?error=1')
end

post("/opencase/:id") do

    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    caseid = params[:id]

    #odds at 50:20:15:10:5
    condition_float = rand()
    caseRoll = rand()
    if caseRoll <= 0.05 
        rarity = 5
    elsif caseRoll <= 0.15 
        rarity = 4
    elsif caseRoll <= 0.3 
        rarity = 3
    elsif caseRoll <= 0.5
        rarity = 2
    else
        rarity = 1
    end

    db = SQLite3::Database.new('db/database.db')
    db.results_as_hash = true

    user_id = db.execute("SELECT id FROM user WHERE id = ?", decoded_token[0]['sub'])
    item_id = db.execute("SELECT id FROM item WHERE case_id = #{caseid} AND rarity_class = #{rarity}")

    db.execute("INSERT INTO u_item (user_id, item_id, condition_float) VALUES (?, ?, ?)", user_id[0]["id"], item_id[0]["id"], condition_float)

    db.close

    redirect('/')
end
