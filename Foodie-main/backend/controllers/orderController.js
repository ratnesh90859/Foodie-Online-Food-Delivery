import orderModel from "../models/orderModel.js";
import userModel from '../models/userModel.js';
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// Placing user order for frontend
const placeOrder = async (req, res) => {
    const frontend_url = "http://localhost:5173";
    try {
        // Create and save new order
        const newOrder = new orderModel({
            userId: req.body.userId,
            items: req.body.items,
            amount: req.body.amount,
            address: req.body.address
        });
        await newOrder.save();

        // Clear user's cart data
        await userModel.findByIdAndUpdate(req.body.userId, { cartData: {} });

        // Prepare line items for Stripe Checkout
        const line_items = req.body.items.map((item) => ({
            price_data: {
                currency: 'inr', // Make sure all prices are in the same currency
                product_data: {
                    name: item.name,
                },
                unit_amount: item.price * 100, // Amount in cents
            },
            quantity: item.quantity,
        }));

        // Add delivery charges to line items
        line_items.push({
            price_data: {
                currency: "inr", // Use the same currency as above
                product_data: {
                    name: "Delivery Charges",
                },
                unit_amount: 2 * 100, // Amount in cents
            },
            quantity: 1,
        });

        // Create a Stripe Checkout session
        const session = await stripe.checkout.sessions.create({
            line_items: line_items,
            mode: 'payment',
            success_url: `${frontend_url}/verify?success=true&orderId=${newOrder._id}`,
            cancel_url: `${frontend_url}/verify?success=false&orderId=${newOrder._id}`
        });

        res.json({ success: true, session_url: session.url });
    } catch (error) {
        console.log(error);
        res.status(500).json({ success: false, message: error.message });
    }
}
const verifyOrder = async (req, res) => {
    const { orderId, success } = req.body;
    try {
        if (success == "true") {
            await orderModel.findByIdAndUpdate(orderId, { payment: true });
            res.json({ success: true, message: "Paid" });
        } else {
            await orderModel.findByIdAndDelete(orderId);
            res.json({ success: false, message: "Order deleted" });
        }
    } catch (error) {
        console.log(error);
        res.json({ success: false, message: "Server error" });
    }
}
//user order for frontend
const userOrders = async (req, res) => {
    try {
      const orders = await orderModel.find({ userId: req.body.userId });
      res.json({ success: true, data: orders });
    } catch (error) {
      console.log(error);
      res.json({ success: false, message: "Error" });
    }
  }

  //listing orders for admin pannel
  const listOrders = async (req, res) => {
    try {
      const orders = await orderModel.find({});//display all orders
      res.json({ success: true, data: orders });
    } catch (error) {
      console.log(error);
      res.json({ success: false, message: "Error" });
    }
  }

  //api for updating order status
  const updateOrderStatus = async (req, res) =>{
    try {
      await orderModel.findByIdAndUpdate(
        req.body.orderId,
        { status: req.body.status }
      );
      res.json({ success: true, message: "Status Updated" });
    } catch (error) {
      console.log(error);
      res.json({ success: false, message: "Error" });
    }
  };

  
  

export { placeOrder,verifyOrder,userOrders,listOrders,updateOrderStatus };
