from flask import Flask, request, jsonify
import pyodbc
import math
from datetime import datetime, timedelta, timezone
import smtplib
from flask import Flask, request, jsonify
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

app = Flask(__name__)

from flask_cors import CORS
CORS(app, origins=["http://localhost:*", "http://10.0.2.2:5000", "http://192.168.1.6:5000","http://192.168.0.107:5000"])

from dotenv import load_dotenv
import os

load_dotenv()  # Load variables from .env

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_SERVICE = os.getenv("DB_SERVICE")

MAIL_USERNAME = os.getenv("MAIL_USERNAME")
MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")
SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT"))

# Connection String
CONN_STR = (
    f"DRIVER={{Oracle23}};"
    f"DBQ=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={DB_HOST})(PORT={DB_PORT}))"
    f"(CONNECT_DATA=(SERVICE_NAME={DB_SERVICE})));"
    f"UID={DB_USER};PWD={DB_PASSWORD}"
)


# Function to get database connection
def get_db_connection():
    return pyodbc.connect(CONN_STR)

# Function to send fancy HTML emails
def send_email(recipient, subject, html_body):
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = MAIL_USERNAME
    msg["To"] = recipient

    part = MIMEText(html_body, "html")
    msg.attach(part)

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(MAIL_USERNAME, MAIL_PASSWORD)
            server.sendmail(MAIL_USERNAME, recipient, msg.as_string())
            print("✅ Email sent successfully.")
    except Exception as e:
        print(f"❌ Email sending failed: {e}")

# Route: User Registration
@app.route('/register', methods=['POST'])
def register_user():
    data = request.json
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if email already exists
        cursor.execute("SELECT 1 FROM Customer WHERE Email = ?", (data["email"],))
        if cursor.fetchone():
            return jsonify({"error": "Email already registered"}), 400
        
        # Generate unique user ID
        users = str(len(cursor.execute("SELECT * FROM Customer").fetchall()) + 1).zfill(3)
        user_id = f"CUST{users}"
        
        # Insert new user
        query = """
            INSERT INTO Customer (Customer_ID, Name, Email, Phone_Number, Password) 
            VALUES (?, ?, ?, ?, ?)
        """
        cursor.execute(query, (user_id, data["name"], data["email"], data["phone"], data["password"]))
        conn.commit()
        
        # Send styled confirmation email
        html_message = f"""
        <html>
          <body style="font-family: Arial, sans-serif; background-color: #f9f9f9; padding: 20px;">
            <div style="max-width: 600px; margin: auto; background-color: #ffffff; padding: 30px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1);">
              <h2 style="color: #ff6600;">Welcome to SavorGo 🍽️</h2>
              <p>Hello <strong>{data["name"]}</strong>,</p>
              <p>Your account has been <strong>successfully created</strong>! 🎉</p>
              <p><b>Your User ID:</b> {user_id}</p>
              <p>We’re excited to have you with us. Start exploring and ordering delicious meals near you!</p>
              <hr style="border: none; border-top: 1px solid #eee;">
              <p style="font-size: 14px; color: #888;">If you did not sign up, please ignore this email.</p>
              <p style="font-size: 14px; color: #888;">– The SavorGo Team</p>
            </div>
          </body>
        </html>
        """

        send_email(data["email"], "🎉 Welcome to SavorGo!", html_message)

        return jsonify({"message": "User registered successfully", "User_ID": user_id}), 201

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

# Route: User Login
@app.route('/login', methods=['POST'])
def login_user():
    data = request.json
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT Customer_ID, Name, Email, Password FROM Customer WHERE Email = ?", (data["email"],))
        user = cursor.fetchone()
        if user and user[3] == data["password"]:
            return jsonify({
                "message": "Login successful",
                "User_ID": user[0],
                "name": user[1],
                "email": user[2]
            }), 200
        else:
            return jsonify({"error": "Invalid email or password"}), 401
        
    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
        
@app.route('/add_address', methods=['POST'])
def add_address():
    data = request.json

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        user_id = data.get("User_ID")
        address = data.get("address")
        latitude = data.get("latitude")
        longitude = data.get("longitude")

        if not user_id or not address:
            return jsonify({"error": "User_ID or address is missing"}), 400

        # Check if Customer exists and has Address_ID
        cursor.execute("SELECT Address_ID FROM Customer WHERE Customer_ID = ?", (user_id,))
        result = cursor.fetchone()

        if result and result[0]:
            address_id = result[0]

            # Update existing address
            query = """
                UPDATE Address 
                SET Address = ?, Latitude = ?, Longitude = ?
                WHERE Address_ID = ?
            """
            cursor.execute(query, (address, latitude, longitude, address_id))
        else:
            # Generate new Address_ID
            cursor.execute("SELECT COUNT(*) FROM Address")
            count = str(int(cursor.fetchone()[0])+1).zfill(3)
            address_id = f"ADDR0{count}"

            # Insert new address
            insert_query = """
                INSERT INTO Address (Address_ID, Address, Latitude, Longitude) 
                VALUES (?, ?, ?, ?)
            """
            cursor.execute(insert_query, (address_id, address, latitude, longitude))

            # Update Customer with new Address_ID
            update_customer = "UPDATE Customer SET Address_ID = ? WHERE Customer_ID = ?"
            cursor.execute(update_customer, (address_id, user_id))

        conn.commit()
        return jsonify({"message": "Address added/updated successfully"}), 200

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

def haversine(lat1, lon1, lat2, lon2):
    # Radius of the Earth in km
    R = 6371.0  
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

@app.route('/invoice', methods=['GET'])
def get_distance():
    restaurant_id = request.args.get("restaurant_id")
    user_id = request.args.get("user_id")

    if not restaurant_id or not user_id:
        return jsonify({"error": "Missing parameters"}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get user's address coordinates
        cursor.execute("SELECT Address_ID FROM Customer WHERE Customer_ID = ?", (user_id,))
        address_result = cursor.fetchone()
        if not address_result:
            return jsonify({"error": "Customer not found"}), 404

        address_id = address_result[0]

        cursor.execute("SELECT Latitude, Longitude FROM Address WHERE Address_ID = ?", (address_id,))
        coords_result = cursor.fetchone()
        if not coords_result:
            return jsonify({"error": "Address not found"}), 404

        user_lat, user_lon = coords_result

        cursor.execute("""
            SELECT A.Latitude, A.Longitude
            FROM Restaurant R
            JOIN Address A ON R.Address_ID = A.Address_ID 
            WHERE R.Restaurant_ID = ?
        """, (restaurant_id,))
        coords_result = cursor.fetchone()
        if not coords_result:
            return jsonify({"error": "Restaurant not found"}), 404

        restaurant_lat, restaurant_lon = coords_result

        distance = haversine(user_lat, user_lon, restaurant_lat, restaurant_lon)

        return jsonify({"distance_km": distance}), 200

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()


@app.route('/restaurants/<user_id>', methods=['GET'])
def get_restaurants(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get user's address coordinates
        cursor.execute("SELECT Address_ID FROM Customer WHERE Customer_ID = ?", (user_id,))
        address_result = cursor.fetchone()
        if not address_result:
            return jsonify({"error": "Customer not found"}), 404

        address_id = address_result[0]

        cursor.execute("SELECT Latitude, Longitude FROM Address WHERE Address_ID = ?", (address_id,))
        coords_result = cursor.fetchone()
        if not coords_result:
            return jsonify({"error": "Address not found"}), 404

        user_lat, user_lon = coords_result

        # Get restaurant details and coordinates
        cursor.execute("""
            SELECT R.Restaurant_ID, R.Restaurant_Name, R.Address_ID, A.Latitude, A.Longitude
            FROM Restaurant R
            JOIN Address A ON R.Address_ID = A.Address_ID
        """)
        nearby_restaurants = []

        for row in cursor.fetchall():
            rest_id, rest_name, rest_address_id, rest_lat, rest_lon = row
            distance = haversine(user_lat, user_lon, rest_lat, rest_lon)
            if distance <= 7:
                cursor.execute("SELECT AVG(Rating) FROM Review WHERE Restaurant_ID = ?", (rest_id,))
                rating_result = cursor.fetchone()
                rating = rating_result[0] or 0.0

                nearby_restaurants.append({
                    "id": rest_id,
                    "name": rest_name,
                    "address_id": rest_address_id,
                    "distance_km": round(distance, 2),
                    "rating": round(rating, 2)
                })

        # Sort by nearest and highest rating
        nearby_restaurants.sort(key=lambda x: (x["distance_km"], -x["rating"]))

        return jsonify({"restaurants": nearby_restaurants})

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()


        
@app.route('/menu/<restaurant_id>', methods=['GET'])
def get_menu(restaurant_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(f"SELECT Item_ID, Item_Name, Description, Price FROM Menu_Item WHERE Restaurant_ID = '{restaurant_id}'")
        
        menu_items = [{"Item_ID": row[0], "Item_Name": row[1], "Description": row[2], "Price": row[3]} for row in cursor.fetchall()]
        return jsonify({"menu": menu_items}) , 200

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()

@app.route('/cart/add', methods=['POST'])
def add_to_cart():
    data = request.json
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        customer_id = data["Customer_ID"]
        print(customer_id)
        item_id = data["Item_ID"]
        quantity = data["Quantity"]

        cursor.execute("""
            SELECT Quantity FROM Cart WHERE Customer_ID = ? AND Item_ID = ?
        """, (customer_id, item_id))
        
        existing_item = cursor.fetchone()

        if existing_item:
            new_quantity = existing_item[0] + quantity
            cursor.execute("""
                UPDATE Cart SET Quantity = ? WHERE Customer_ID = ? AND Item_ID = ?
            """, (new_quantity, customer_id, item_id))
        else:
            cursor.execute("SELECT cart_id_seq.NEXTVAL FROM DUAL")
            cart_seq = cursor.fetchone()[0]
            cart_id = f"CART{str(cart_seq).zfill(6)}"
            cursor.execute("""
                INSERT INTO Cart (Cart_ID, Customer_ID, Item_ID, Quantity) 
                VALUES (?, ?, ?, ?)
            """, (cart_id, customer_id, item_id, quantity))

        conn.commit()
        return jsonify({"message": "Item added to cart"}), 201

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/cart/remove', methods=['POST'])
def remove_from_cart():
    data = request.json
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        customer_id = data["Customer_ID"]
        item_id = data["Item_ID"]

        cursor.execute("""
            SELECT Quantity FROM Cart WHERE Customer_ID = ? AND Item_ID = ?
        """, (customer_id, item_id))
        
        existing_item = cursor.fetchone()

        if existing_item:
            current_quantity = existing_item[0]
            if current_quantity > 1:
                cursor.execute("""
                    UPDATE Cart SET Quantity = ? WHERE Customer_ID = ? AND Item_ID = ?
                """, (current_quantity - 1, customer_id, item_id))
            else:
                cursor.execute("""
                    DELETE FROM Cart WHERE Customer_ID = ? AND Item_ID = ?
                """, (customer_id, item_id))

            conn.commit()
            return jsonify({"message": "Item removed from cart"}), 200
        else:
            return jsonify({"message": "Item not found in cart"}), 404

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/cart/<customer_id>', methods=['GET'])
def get_cart(customer_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT c.Item_ID, m.Item_Name, m.Price, c.Quantity 
            FROM Cart c 
            JOIN Menu_Item m ON c.Item_ID = m.Item_ID 
            WHERE c.Customer_ID = ?
        """, (customer_id,))
        cart_items = [
            {"item_id": row[0], "name": row[1], "price": row[2], "quantity": row[3]}
            for row in cursor.fetchall()
        ]
        return jsonify({"cart": cart_items})
    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/orders/<customer_id>', methods=['GET'])
def get_past_orders(customer_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT Order_ID, Order_Status, Total_Amount
            FROM Order_Details
            WHERE Customer_ID = ?
            ORDER BY Order_Time DESC
        """, (customer_id,))

        orders = cursor.fetchall()
        order_list = []

        for order in orders:
            order_list.append({
                "orderId": order[0],
                "status": order[1],
                "total": f"₹{float(order[2]):.2f}"
            })

        return jsonify({"orders": order_list}), 200

    except Exception as e:
        print("❌ Error fetching orders:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()
        
@app.route('/order/place', methods=['POST'])
def place_order():
    data = request.json
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        customer_id = data["Customer_ID"]

        # Get cart items
        cursor.execute("""
            SELECT c.Item_ID, c.Quantity, m.Price, m.Restaurant_ID
            FROM Cart c
            JOIN Menu_Item m ON c.Item_ID = m.Item_ID
            WHERE c.Customer_ID = ?
        """, (customer_id,))
        items = cursor.fetchall()

        if not items:
            return jsonify({"error": "Cart is empty"}), 400

        restaurant_ids = list(set([item[3] for item in items]))
        if len(restaurant_ids) != 1:
            return jsonify({"error": "All cart items must be from the same restaurant"}), 400

        restaurant_id = restaurant_ids[0]

        # Generate Order_ID
        cursor.execute("SELECT order_id_seq.NEXTVAL FROM DUAL")
        order_seq = cursor.fetchone()[0]
        order_id = f"ORD{str(order_seq).zfill(6)}"

        total_amount = sum(float(qty) * float(price) for _, qty, price, _ in items)

        customer_lat, customer_lon = cursor.execute("""
            SELECT A.Latitude, A.Longitude 
            FROM Address A 
            JOIN Customer C ON A.Address_ID = C.Address_ID 
            WHERE C.Customer_ID = ?
        """, (customer_id,)).fetchone()

        restaurant_address = cursor.execute("""
            SELECT Address_ID FROM Restaurant WHERE Restaurant_ID = ?
        """, (restaurant_id,)).fetchone()[0]

        cursor.execute("""
            INSERT INTO Order_Details (
                Order_ID, Customer_ID, Restaurant_ID, Order_Status, 
                Total_Amount, Customer_Latitude, Customer_Longitude, Restaurant_Address
            )
            VALUES (?, ?, ?, 'Pending', ?, ?, ?, ?)
        """, (order_id, customer_id, restaurant_id, total_amount, customer_lat, customer_lon, restaurant_address))

        cursor.execute("SELECT COUNT(*) FROM Order_Item")
        item_count = int(cursor.fetchone()[0])
        item_lines = ""

        for i, (item_id, qty, price, _) in enumerate(items, start=1):
            cursor.execute("SELECT order_item_id_seq.NEXTVAL FROM DUAL")
            item_seq = cursor.fetchone()[0]
            order_item_id = f"ORDITEM{str(item_seq).zfill(6)}"
            cursor.execute("""
                INSERT INTO Order_Item (Order_Item_ID, Order_ID, Item_ID, Quantity, Price)
                VALUES (?, ?, ?, ?, ?)
            """, (order_item_id, order_id, item_id, qty, price))

            item_name = cursor.execute("SELECT Item_Name FROM Menu_Item WHERE Item_ID = ?", (item_id,)).fetchone()[0]
            subtotal = float(qty) * float(price)
            item_lines += f"<tr><td>{item_name}</td><td>{qty}</td><td>₹{price:.2f}</td><td>₹{subtotal:.2f}</td></tr>"

        cursor.execute("DELETE FROM Cart WHERE Customer_ID = ?", (customer_id,))

        coords_result = cursor.execute("""
            SELECT A.Latitude, A.Longitude
            FROM Restaurant R
            JOIN Address A ON R.Address_ID = A.Address_ID 
            WHERE R.Restaurant_ID = ?
        """, (restaurant_id,)).fetchone()

        if not coords_result:
            return jsonify({"error": "Restaurant not found"}), 404

        restaurant_lat, restaurant_lon = coords_result
        distance_km = haversine(customer_lat, customer_lon, restaurant_lat, restaurant_lon)
        IST = timezone(timedelta(hours=5, minutes=30))
        current_time_ist = datetime.now(IST)
        delivery_seconds = int(distance_km * 90)
        estimated_time = current_time_ist + timedelta(seconds=delivery_seconds)

        email = cursor.execute("SELECT Email FROM Customer WHERE Customer_ID = ?", (customer_id,)).fetchone()[0]
        restaurant_name = cursor.execute("SELECT RESTAURANT_NAME FROM Restaurant WHERE Restaurant_ID = ?", (restaurant_id,)).fetchone()[0]

        # HTML Invoice Email
        email_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; background-color: #f7f7f7; padding: 20px;">
            <div style="max-width: 600px; margin: auto; background-color: #fff; padding: 25px; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1);">
                <h2 style="color: #ff6600;">SavorGo Order Invoice 🧾</h2>
                <p><strong>Order ID:</strong> {order_id}</p>
                <p><strong>Restaurant :</strong> {restaurant_name}</p>
                <table width="100%" style="border-collapse: collapse; margin-top: 20px;">
                    <thead>
                        <tr style="background-color: #f2f2f2;">
                            <th align="left">Item</th>
                            <th align="center">Qty</th>
                            <th align="center">Price</th>
                            <th align="center">Subtotal</th>
                        </tr>
                    </thead>
                    <tbody>
                        {item_lines}
                    </tbody>
                </table>
                <p style="margin-top: 20px;"><strong>Total Amount:</strong> ₹{total_amount:.2f}</p>
                <p><strong>Estimated Delivery Time:</strong> {estimated_time}</p>
                <hr>
                <p style="color: #777;">Thanks for ordering with us! Enjoy your meal 🍽️</p>
                <p style="font-size: 14px; color: #aaa;">– SavorGo Team</p>
            </div>
        </body>
        </html>
        """

        send_email(email, f"🧾 Invoice for Order {order_id}", email_body)
        conn.commit()
        return jsonify({"message": "Order placed successfully", "Order_ID": order_id}), 201

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route('/order/details/<order_id>', methods=['GET'])
def get_order_details(order_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get order and restaurant info
        cursor.execute("""
            SELECT o.Total_Amount, r.Restaurant_Name, r.Restaurant_ID
            FROM Order_Details o
            JOIN Restaurant r ON o.Restaurant_ID = r.Restaurant_ID
            WHERE o.Order_ID = ?
        """, (order_id,))
        order_row = cursor.fetchone()

        if not order_row:
            return jsonify({"error": "Order not found"}), 404

        total_amount, restaurant_name, restaurant_id = order_row

        # Get ordered items
        cursor.execute("""
            SELECT m.Item_Name, oi.Price, oi.Quantity
            FROM Order_Item oi
            JOIN Menu_Item m ON oi.Item_ID = m.Item_ID
            WHERE oi.Order_ID = ?
        """, (order_id,))
        items = cursor.fetchall()

        item_list = [
            {
                "name": row[0],
                "price": float(row[1]),
                "quantity": row[2]
            }
            for row in items
        ]

        return jsonify({
            "orderId": order_id,
            "restaurantName": restaurant_name,
            "restaurantId": restaurant_id,
            "total": float(total_amount),
            "items": item_list
        }), 200

    except Exception as e:
        print("❌ Error fetching order details:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()


@app.route('/track_order/<order_id>', methods=['GET'])
def get_location(order_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Get Customer_ID and Restaurant_ID for the order
        cursor.execute("SELECT Order_Time , Customer_Latitude , Customer_Longitude , Restaurant_Address FROM Order_Details WHERE Order_ID = ?", (order_id,))
        result = cursor.fetchone()
        if not result:
            return jsonify({"error": "Order not found"}), 404

        order_time , customer_lat , customer_lon, restaurant_address = result

        user_lat, user_lon = customer_lat , customer_lon

        # Get restaurant's address coordinates
        cursor.execute("SELECT Latitude, Longitude FROM Address WHERE Address_ID = ?", (restaurant_address,))
        rest_coords = cursor.fetchone()
        if not rest_coords:
            return jsonify({"error": "Restaurant not found"}), 404

        restaurant_lat, restaurant_lon = rest_coords

        # Calculate distance using your haversine function
        distance = haversine(user_lat, user_lon, restaurant_lat, restaurant_lon)

        # Return JSON with all required info
        return jsonify({
            "order_time" : order_time.isoformat(),
            "user": {
                "latitude": user_lat,
                "longitude": user_lon
            },
            "restaurant": {
                "latitude": restaurant_lat,
                "longitude": restaurant_lon
            },
            "distance_km": round(distance, 2)
        })

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()

@app.route('/track_order/update', methods=['POST'])
def update_order_status():
    try:
        data = request.get_json()
        order_id = data.get('orderId')

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "UPDATE Order_Details SET Order_Status = 'Delivered' WHERE Order_Id = ?",
            (order_id,)
        )
        conn.commit()

        return jsonify({"message": "Order status updated successfully"}), 200

    except Exception as e:
        print("❌ Error updating order status:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()

@app.route('/payment', methods=['POST'])
def process_payment():
    data = request.json
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        order_id = data["Order_ID"]
        payments = str(int(cursor.execute("SELECT COUNT(*) FROM Payment").fetchone()[0]) + 1).zfill(3)
        payment_id = f"PAY{payments}"

        cursor.execute("""
            INSERT INTO Payment (Payment_ID, Order_ID, Payment_Status)
            VALUES (?, ?, 'Success')
        """, (payment_id, order_id))

        conn.commit()
        return jsonify({"message": "Payment successful", "Payment_ID": payment_id}), 201

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/user/<user_id>', methods=['GET'])
def get_user_details(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT Name, Email, Phone_Number FROM Customer WHERE Customer_ID = ?
        """, (user_id,))

        user = cursor.fetchone()
        if user:
            return jsonify({"name": user[0], "email": user[1], "phone": user[2]}), 200
        else:
            return jsonify({"error": "User not found"}), 404

    except Exception as e:
        print("❌ Error:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()



@app.route('/review', methods=['POST'])
def add_review():
    data = request.json

    customer_id = data.get("customer_id")
    restaurant_id = data.get("restaurant_id")
    rating = data.get("rating")
    review_text = data.get("review_text")
    review_date = datetime.now()

    if not all([customer_id, restaurant_id, rating]):
        return jsonify({"error": "Missing required fields"}), 400

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Generate new Review_ID based on count + 1
        cursor.execute("SELECT review_seq.NEXTVAL FROM dual")
        next_val = cursor.fetchone()[0]
        new_review_id = f"REV{str(next_val).zfill(3)}"

        cursor.execute("""
            INSERT INTO Review (
                Review_ID, Customer_ID, Restaurant_ID, Rating, Review_Text, Review_Date
            ) VALUES (?, ?, ?, ?, ?, ?)
        """, (new_review_id, customer_id, restaurant_id, rating, review_text, review_date))

        conn.commit()
        return jsonify({"message": "Review submitted successfully!"}), 201

    except Exception as e:
        print("❌ DB Error:", e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()

@app.route('/customer/details/<customer_id>', methods=['GET'])
def get_customer(customer_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT Name, Email, Phone_Number, Password 
            FROM Customer 
            WHERE Customer_ID = ?
        """, [customer_id])
        row = cursor.fetchone()
        
        if row:
            result = {
                "name": row[0],
                "email": row[1],
                "phone_number": row[2],
                "password": row[3]
            }
            return jsonify(result), 200
        else:
            return jsonify({"error": "Customer not found"}), 404
    
    except Exception as e:
        print("❌ DB Error:", e)
        return jsonify({"error": str(e)}), 500
    
    finally:
        cursor.close()
        conn.close()

@app.route('/customer/update/<customer_id>', methods=['PUT'])
def update_customer(customer_id):
    data = request.json
    name = data.get("name")
    email = data.get("email")
    phone = data.get("phone_number")
    password = data.get("password")

    if not all([name, email, phone, password]):
        return jsonify({"error": "Missing fields in request"}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            UPDATE Customer
            SET Name = ?,
                Email = ?,
                Phone_Number = ?,
                Password = ?
            WHERE Customer_ID = ?
        """, (name , email , phone , password , customer_id))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({"error": "Customer not found"}), 404
        return jsonify({"message": "Customer updated successfully"}), 200
    
    except Exception as e:
        print("❌ DB Error:", e)
        return jsonify({"error": str(e)}), 500
    
    finally:
        cursor.close()
        conn.close()


if __name__ == '__main__':        
    app.run(host="0.0.0.0", port=5000,debug=True)

