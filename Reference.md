

Goal: 

- Automate steps of the data audit process

References:

- [Booking tool data export](https://docs.google.com/spreadsheets/d/1GzOyPaVY2nu9raQlEQlf6jWV2ebhKqF0gTnpoaZt31k/edit?usp=sharing)  
  - Sort data by:  
    - Overall usage  
      - \#reservations  
        - Include: Approved, Checked out  
      - \#hours  
    - Department   
      - \#reservations  
      - \#hours  
    - School  
      - \#reservations  
      - \#hours  
    - Room  
      - \#reservations  
      - \#hours  
    - \+Booking Type  
      - \#reservations  
      - \#hours  
  - Make sure  
    - Hours are correct (capping each day at 12 hours max)  
    - Do not include maintenance reservations  
    - Do not include: Canceled, declined, no show  
- [Completed AY25 Data audit](https://docs.google.com/spreadsheets/d/1T5TdU9RymIrWgPpoezNlMwSPaXsdgKBj3WoD9W3NTdA/edit?usp=sharing)   
- [AY22-AY25 Data Audit Top Sheet](https://docs.google.com/spreadsheets/d/1h5eT6heuKIe3Thyv_Kpa-VECBYmslasHm_M8wziNIdc/edit?usp=sharing) 

Notes

- App script can be slow when running with a lot of rows  
- Relational database \- split up data by categories


Next Steps:

- Completed app and documentation   
  - Including how to update the script 