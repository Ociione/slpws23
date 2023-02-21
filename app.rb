require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'jwt'

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

    # db = SQLite3::Database.new('db/database.db')
    # db.results_as_hash = true

    # cases = db.execute("SELECT * FROM case")
    # balance = db.execute("SELECT balance FROM user WHERE id = ?")

    # db.close

    slim(:index)
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
    starting_balance = 5.0

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