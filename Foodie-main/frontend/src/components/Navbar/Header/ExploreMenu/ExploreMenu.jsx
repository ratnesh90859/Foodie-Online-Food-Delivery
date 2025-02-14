import React from 'react';
//import PropTypes from 'prop-types';
import './ExploreMenu.css';
import { menu_list } from '../../../../assets/assets';

const ExploreMenu = ({ category, setCategory }) => {
  return (
    <div className='explore-menu' id='explore-menu'>
      <h1>Explore Menu</h1>
      <p className='explore-menu-text'>
        Selecting a food menu from a list involves considering dietary preferences, balancing flavors, and ensuring variety. Opt for a mix of appetizers, main courses, and desserts. Include options for vegetarians and non-vegetarians. Prioritize seasonal and fresh ingredients for the best taste and nutritional value.
      </p>
      <div className='explore-menu-list'>
        {menu_list.map((item, index) => (
          <div 
            onClick={() => setCategory(prev => prev === item.menu_name ? "All" : item.menu_name)} 
            key={index} 
            className='explore-menu-list-item'
          >
            <img className={category === item.menu_name ? "active" : ""} src={item.menu_image} alt={item.menu_name} />
            <p>{item.menu_name}</p>
          </div>
        ))}
      </div>
      <hr />
    </div>
  );
};

// ExploreMenu.propTypes = {
//   category: PropTypes.string.isRequired,
//   setCategory: PropTypes.func.isRequired,
// };

export default ExploreMenu;
