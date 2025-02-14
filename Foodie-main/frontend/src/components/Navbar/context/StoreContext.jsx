import React, { createContext, useEffect, useState } from "react";
import axios from "axios";

export const StoreContext = createContext(null);

const StoreContextProvider = (props) => {
  const [cartItems, setCartItems] = useState({});
  const url = "http://localhost:4000";
  const [token, setToken] = useState("");
  const [food_list, setFoodList] = useState([]);

  const addToCart = async (itemId) => {
    if (!itemId) return;

    try {
      setCartItems((prev) => ({
        ...prev,
        [itemId]: (prev[itemId] || 0) + 1
      }));

      if (token) {
        await axios.post(
          `${url}/api/cart/add`, 
          { itemId }, 
          { headers: { token } }
        );
      }
    } catch (error) {
      console.error("Error adding to cart:", error);
      // Rollback the cart update if API call fails
      setCartItems((prev) => ({
        ...prev,
        [itemId]: (prev[itemId] || 0)
      }));
    }
  };

  const removeFromCart = async (itemId) => {
    if (!itemId || !cartItems[itemId]) return;

    try {
      setCartItems((prev) => ({
        ...prev,
        [itemId]: Math.max(0, (prev[itemId] || 0) - 1)
      }));

      if (token) {
        await axios.post(
          `${url}/api/cart/remove`, 
          { itemId }, 
          { headers: { token } }
        );
      }
    } catch (error) {
      console.error("Error removing from cart:", error);
      // Rollback the cart update if API call fails
      setCartItems((prev) => ({
        ...prev,
        [itemId]: prev[itemId] || 0
      }));
    }
  };

  const getTotalCartAmount = () => {
    try {
      return Object.entries(cartItems).reduce((total, [itemId, quantity]) => {
        if (quantity > 0) {
          const itemInfo = food_list.find((product) => product._id === itemId);
          if (itemInfo) {
            return total + (itemInfo.price * quantity);
          }
        }
        return total;
      }, 0);
    } catch (error) {
      console.error("Error calculating total:", error);
      return 0;
    }
  };

  const fetchFoodList = async () => {
    try {
      const response = await axios.get(`${url}/api/food/list`);
      if (response.data?.data) {
        setFoodList(response.data.data);
      }
    } catch (error) {
      console.error("Error fetching food list:", error);
      setFoodList([]);
    }
  };

  const loadCartData = async (userToken) => {
    if (!userToken) return;

    try {
      const response = await axios.post(
        `${url}/api/cart/get`, 
        {}, 
        { headers: { token: userToken } }
      );
      if (response.data?.cartData) {
        setCartItems(response.data.cartData);
      }
    } catch (error) {
      console.error("Error loading cart data:", error);
      setCartItems({});
    }
  };

  useEffect(() => {
    const loadData = async () => {
      await fetchFoodList();
      const storedToken = localStorage.getItem("token");
      if (storedToken) {
        setToken(storedToken);
        await loadCartData(storedToken);
      }
    };
    loadData();
  }, []);

  const contextValue = {
    food_list,
    cartItems,
    setCartItems,
    addToCart,
    removeFromCart,
    getTotalCartAmount,
    url,
    token,
    setToken,
  };

  return (
    <StoreContext.Provider value={contextValue}>
      {props.children}
    </StoreContext.Provider>
  );
};

export default StoreContextProvider;