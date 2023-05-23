require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'jwt'
require_relative 'model.rb'
include Model

enable :sessions

get('/') do
    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    db = db_initiate()
    skrin = data_cases(db)
    balance = balance_data(db, decoded_token)
    email = mail_userdata(db, decoded_token) 
    items = item_data(db, decoded_token)
    name = user_item_rel(db, decoded_token)
    rarity = user_rarity_rel(db, decoded_token)
    users = user_data(db)
    admin = admin_status(db, decoded_token)
    db.close

    j = 0

    slim(:index, locals:{skrin:skrin, balance:balance, email:email, items:items, name:name, rarity:rarity, users:users, j:j, admin:admin})
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

    password = BCrypt::Password.create(params['password'])

    starting_balance = 60.0

    db = db_initiate()

    begin
        reg_user(db, email, password, starting_balance)
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

    db = db_initiate()
    result = user_email_data(db, email)
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

post('/logout') do

    session[:token] = nil

    redirect('/')

end

post('/deleteuser/:id') do
    user_id = params[:id]

    db = db_initiate()

    deleteuser(db, user_id)

    redirect('/')
end

get("/deposit/?") do

    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    db = db_initiate()
    user_id = user_id_get(db, decoded_token) 
    db.close

    balance_change("add", params[:amount].to_i, user_id[0]["id"])

    redirect('/')

end

get("/withdraw/?") do

    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    db = db_initiate()
    user_id = user_id_get(db, decoded_token)
    db.close

    balance_change("remove", params[:amount].to_i, user_id[0]["id"])

    redirect('/')

end

post("/opencase/:id") do

    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    caseid = params[:id]

    db = db_initiate()

    user_id = user_id_get(db, decoded_token)
    current_balance = get_balance(db, user_id)
    case_price = get_case_price(db, caseid)

    p current_balance
    p case_price

    if current_balance[0]["balance"] >= case_price[0]["buy_price"]

        #odds at 50:20:15:10:5
        condition_float = rand().round(3)
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

        item_id = get_itemid(db, caseid, rarity)
        b_price = get_bprice(db, item_id)
        price = ((b_price[0]["base_price"]) / (condition_float + 0.5)).round(3)

        p case_price[0]["buy_price"]
        p user_id[0]["id"]

        balance_change("remove", case_price[0]["buy_price"], user_id[0]["id"])

        new_item(db, user_id, item_id, condition_float, price)

    end

    db.close

    redirect('/')
end

post("/sellItem/:id") do

    token = session[:token]
    verified, decoded_token = verify_token(token)
    if !verified
        redirect('/login')
    end

    itemid = params[:id]

    db = db_initiate()

    items_id = get_uitemid(db, itemid, decoded_token)
    item_price = get_itemprice(db, itemid)
    user_id = user_id_get(db, decoded_token)

    if items_id[0]["id"].to_s == itemid
        deleteitem(db, items_id)
    end

    balance_change("add", item_price[0]["price"], user_id[0]["id"])

    db.close

    redirect('/')
end
