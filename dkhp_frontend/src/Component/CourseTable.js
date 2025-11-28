import React, { useContext } from "react"; 
import TableHeader from "./TableHeader";
import { formatDate } from "../Util/FormatDateTime.js";
import { ClientContext } from "../Router/ClientRouter.js";
const CourseTable=({filterCourses,checkedIds,setCheckedIds})=>{
            const {regNumbers}=useContext(ClientContext);
            const handleCheckbox=(e,id)=>{
                    setCheckedIds(prevIds=>{
                        var updateIds=new Set([...prevIds]);
                        if(e.target.checked) updateIds.add(id);
                        else updateIds.delete(id);
                        return updateIds;
                    });
            }
        return (
                    <div className="TableWapper border-bottom border-dark">
                        <table className="table table-hover">
                            <TableHeader data={["Chọn","Mã Lớp","Môn học","SốTC","Thời gian học","ĐãDK/Sĩ số"]} />
                            <tbody>
                        {filterCourses?.map((data)=> {
                                return (
                                    <tr key={data.id}>
                                        <th scope="row"><input type="checkbox" className="form-check-input" onChange={(e)=>handleCheckbox(e,data.id)} checked={checkedIds.has(data.id)}/></th>
                                        <td>{data.courseId}</td>
                                        <td>{data.subject.subjectName}</td>
                                        <td>{data.subject.theoryCreditNumber}</td>
                                        <td>Thứ {data.dayOfWeek}, tiết {data.beginShift}-{data.endShift}, giảng viên: {data.lecturerName==undefined?'Chưa có':data.lecturerName}, 
                                        ngôn ngữ: {data.language}, cách tuần: {data.weekDistance}, từ {formatDate(data.beginDate)} đến {formatDate(data.endDate)}</td>
                                        <td>{regNumbers.get(data.id+"")}/{data.totalNumber}</td>
                                    </tr>
                                )
                            })}
                            </tbody>
                        </table>
                    </div>
                );
}
export default CourseTable;