import React from 'react';
import './FoodItem.css';
import { assets } from '../../assets/assets';
import { StoreContext } from '../Navbar/context/StoreContext';

const FoodItem = ({ id, name, price, description, image }) => {
  const { cartItems, addToCart, removeFromCart, url } = React.useContext(StoreContext);
  
  // Safely access cart item count
  const itemCount = cartItems?.[id] || 0;

  const handleAddToCart = () => {
    if (id) {
      addToCart(id);
    }
  };

  const handleRemoveFromCart = () => {
    if (id && itemCount > 0) {
      removeFromCart(id);
    }
  };

  return (
    <div className='food-item'>
      <div className="food-item-img-container">
        <img 
          className='food-item-image' 
          src={`${url}/images/${image}`} 
          alt={name} 
        />
      </div>
      <div className='food-item-counter-container'>
        {itemCount === 0 ? (
          <img 
            className='add' 
            onClick={handleAddToCart} 
            src={assets.add_icon_white} 
            alt="Add to cart" 
          />
        ) : (
          <div className='food-item-counter'>
            <img 
              onClick={handleRemoveFromCart} 
              src={assets.remove_icon_red} 
              alt="Remove from cart" 
            />
            <p>{itemCount}</p>
            <img 
              onClick={handleAddToCart} 
              src={assets.add_icon_green} 
              alt="Add more" 
            />
          </div>
        )}
      </div>
      <div className='food-item-info'>
        <div className='food-item-name-rating'>
          <p>{name}</p>
          {/* <img src={assets.rating_stars} alt="Rating" /> */}
        </div>
        <p className='food-item-desc'>{description}</p>
        <p className='food-item-price'>₹{price}</p>
      </div>
    </div>
  );
};

export default FoodItem;