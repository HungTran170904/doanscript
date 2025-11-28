import { useContext } from "react";
import { ClientContext } from "../Router/ClientRouter";
import { formatDate } from "../Util/FormatDateTime";
import { useState } from "react";
import { useEffect } from "react";
import { getEnrolledCourses } from "../API/CourseAPI";

const TimeTablePage=()=>{
          const {courseData, setError}=useContext(ClientContext);
          const[regCourseIds, setRegCourseIds]=useState(new Set());
          const daysOfWeek=["Thứ 2","Thứ 3","Thứ 4","Thứ 5","Thứ 6","Thứ 7"]
          const TimeOfShifts=["7:30 - 8:15","8:15 - 9:00","9:00 - 9:45","10:00 - 10:45","10:45 - 11:30","13:00 - 13:45","13:45 - 14:30","14:30-15:15","15:30-16:15","16:15-17:00"]

          useEffect(()=>{
                    getEnrolledCourses().then(res=>{
                              setRegCourseIds(new Set(res.data))
                    })
                    .catch(err=>setError(err))
         },[])
         const regCourses=courseData.filter((course)=>(regCourseIds.has(course.id)))
        return(
          <div className="main-page">
                              <div  style={{
                                        display: "flex",
                                        flexDirection: "row",
                                        justifyContent: "center",
                                        alignItems: "center",
                              }}>
                                        <h4 className="text-center">THỜI KHOÁ BIỂU TẠM THỜI CÁC MÔN ĐÃ ĐĂNG KÍ</h4>
                    </div>
                    <div className="container">
                              <div className="table-responsive schedule-table">
                                        <table className="table table-bordered text-center fixed-table">
                                        <thead>
                                                  <tr>
                                                      <th className="text-uppercase">Thứ / Tiết</th>
                                                      {daysOfWeek.map((day, index)=>(<th className="text-uppercase" key={index}>{day}</th>))}
                                                  </tr>
                                        </thead>
                                        <tbody>
                                        {TimeOfShifts.map((time,index)=>{
                                                const days=new Array(6).fill(null);
                                                for(let course of regCourses){
                                                    if(course.beginShift<=(index+1)&&(index+1)<=course.endShift) days[course.dayOfWeek-2]=course;
                                                }
                                                  return(
                                                  <tr key={index}>
                                                            <th className="align-middle" style={{backgroundColor: "#F0F1F3"}}>
                                                                <div>Tiết {index+1}</div>
                                                                <div>({time})</div>
                                                            </th>
                                                            {days.map((day, iDay)=>{
                                                                if(day===null) return(<td key={iDay}></td>)
                                                                else if(day.beginShift===(index+1)) return(
                                                                    <td rowSpan={day.endShift-day.beginShift+1} className="align-middle" style={{backgroundColor: "#F0F1F3"}} key={iDay}>
                                                                        <div>{day.courseId}</div>
                                                                        <div>{day.subject.subjectName}</div>
                                                                        <div> Sĩ số: {day.totalNumber}</div>
                                                                        <div>{day.room}</div>
                                                                        <div>BĐ:{formatDate(day.beginDate)}</div>
                                                                        <div>KT:{formatDate(day.endDate)}</div>
                                                                    </td>
                                                                )
                                                            })}
                                                  </tr>
                                                  )
                                        })}
                                        </tbody>
                                        </table>
                              </div>
                    </div>

          </div>
          )
}
export default TimeTablePage;